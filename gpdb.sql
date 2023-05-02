--
-- PostgreSQL database dump
--

-- Dumped from database version 10.6 (Debian 10.6-1.pgdg90+1)
-- Dumped by pg_dump version 10.6 (Debian 10.6-1.pgdg90+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: api; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA api;


ALTER SCHEMA api OWNER TO "user";

--
-- Name: chains; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA chains;


ALTER SCHEMA chains OWNER TO "user";

--
-- Name: dschief; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA dschief;


ALTER SCHEMA dschief OWNER TO "user";

--
-- Name: esm; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA esm;


ALTER SCHEMA esm OWNER TO "user";

--
-- Name: esmv2; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA esmv2;


ALTER SCHEMA esmv2 OWNER TO "user";

--
-- Name: extracted; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA extracted;


ALTER SCHEMA extracted OWNER TO "user";

--
-- Name: extractedarbitrum; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA extractedarbitrum;


ALTER SCHEMA extractedarbitrum OWNER TO "user";

--
-- Name: mkr; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA mkr;


ALTER SCHEMA mkr OWNER TO "user";

--
-- Name: polling; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA polling;


ALTER SCHEMA polling OWNER TO "user";

--
-- Name: postgraphile_watch; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA postgraphile_watch;


ALTER SCHEMA postgraphile_watch OWNER TO "user";

--
-- Name: vulcan2x; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA vulcan2x;


ALTER SCHEMA vulcan2x OWNER TO "user";

--
-- Name: vulcan2xarbitrum; Type: SCHEMA; Schema: -; Owner: user
--

CREATE SCHEMA vulcan2xarbitrum;


ALTER SCHEMA vulcan2xarbitrum OWNER TO "user";

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: delegate_entry; Type: TYPE; Schema: public; Owner: user
--

CREATE TYPE public.delegate_entry AS (
	delegate character varying(66),
	vote_delegate character varying(66),
	creation_date timestamp with time zone,
	expiration_date timestamp with time zone,
	expired boolean,
	last_voted timestamp with time zone,
	delegator_count integer,
	total_mkr numeric(78,18)
);


ALTER TYPE public.delegate_entry OWNER TO "user";

--
-- Name: delegate_order_by_type; Type: TYPE; Schema: public; Owner: user
--

CREATE TYPE public.delegate_order_by_type AS ENUM (
    'DATE',
    'MKR',
    'DELEGATORS',
    'RANDOM'
);


ALTER TYPE public.delegate_order_by_type OWNER TO "user";

--
-- Name: delegation_metrics_entry; Type: TYPE; Schema: public; Owner: user
--

CREATE TYPE public.delegation_metrics_entry AS (
	delegator_count bigint,
	total_mkr_delegated numeric
);


ALTER TYPE public.delegation_metrics_entry OWNER TO "user";

--
-- Name: job_status; Type: TYPE; Schema: public; Owner: user
--

CREATE TYPE public.job_status AS ENUM (
    'processing',
    'stopped',
    'not-ready'
);


ALTER TYPE public.job_status OWNER TO "user";

--
-- Name: order_direction_type; Type: TYPE; Schema: public; Owner: user
--

CREATE TYPE public.order_direction_type AS ENUM (
    'ASC',
    'DESC'
);


ALTER TYPE public.order_direction_type OWNER TO "user";

--
-- Name: active_poll_by_id(integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.active_poll_by_id(arg_poll_id integer) RETURNS TABLE(creator character varying, poll_id integer, block_created integer, start_date integer, end_date integer, multi_hash character varying, url character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT C.creator, C.poll_id, C.block_created, C.start_date, C.end_date, C.multi_hash, C.url
	FROM polling.poll_created_event AS C
	LEFT JOIN polling.poll_withdrawn_event AS W
	ON C.poll_id = W.poll_id AND C.creator = W.creator
	WHERE W.block_withdrawn IS NULL AND C.poll_id = arg_poll_id
	ORDER BY C.end_date;
$$;


ALTER FUNCTION api.active_poll_by_id(arg_poll_id integer) OWNER TO "user";

--
-- Name: active_poll_by_multihash(text); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.active_poll_by_multihash(arg_poll_multihash text) RETURNS TABLE(creator character varying, poll_id integer, block_created integer, start_date integer, end_date integer, multi_hash character varying, url character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT C.creator, C.poll_id, C.block_created, C.start_date, C.end_date, C.multi_hash, C.url
	FROM polling.poll_created_event AS C
	LEFT JOIN polling.poll_withdrawn_event AS W
	ON C.poll_id = W.poll_id AND C.creator = W.creator
	WHERE W.block_withdrawn IS NULL AND C.multi_hash LIKE arg_poll_multihash
	ORDER BY C.end_date;
$$;


ALTER FUNCTION api.active_poll_by_multihash(arg_poll_multihash text) OWNER TO "user";

--
-- Name: active_polls(); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.active_polls() RETURNS TABLE(creator character varying, poll_id integer, block_created integer, start_date integer, end_date integer, multi_hash character varying, url character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT C.creator, C.poll_id, C.block_created, C.start_date, C.end_date, C.multi_hash, C.url
	FROM polling.poll_created_event AS C
	LEFT JOIN polling.poll_withdrawn_event AS W
	ON C.poll_id = W.poll_id AND C.creator = W.creator
	WHERE W.block_withdrawn IS NULL
	ORDER BY C.end_date;
$$;


ALTER FUNCTION api.active_polls() OWNER TO "user";

--
-- Name: all_current_votes(character); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.all_current_votes(arg_address character) RETURNS TABLE(poll_id integer, option_id integer, option_id_raw character, block_timestamp timestamp with time zone, chain_id integer, mkr_support numeric, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
  -- Results in all the votes between the start and end date of each poll voted by arg_address (per chain)
  WITH all_valid_mainnet_votes AS (
    SELECT 
      v.voter,
      v.option_id,
      v.option_id_raw, 
      v.poll_id, 
      v.block_id, 
      b.timestamp as block_timestamp, 
      v.chain_id,
      to_timestamp(c.end_date) as end_timestamp,
      t.hash
    FROM polling.voted_event v
    JOIN polling.poll_created_event c ON c.poll_id=v.poll_id
    JOIN vulcan2x.block b ON v.block_id = b.id
    JOIN vulcan2x.transaction t ON v.tx_id = t.id
    WHERE b.timestamp >= to_timestamp(c.start_date) AND b.timestamp <= to_timestamp(c.end_date)
  ), 
  all_valid_arbitrum_votes AS (
    SELECT 
      va.voter,
      va.option_id, 
      va.option_id_raw, 
      va.poll_id, 
      va.block_id, 
      b.timestamp as block_timestamp, 
      va.chain_id,
      to_timestamp(c.end_date) as end_timestamp,
      t.hash
    FROM polling.voted_event_arbitrum va
    JOIN polling.poll_created_event c ON c.poll_id=va.poll_id
    JOIN vulcan2xarbitrum.block b ON va.block_id = b.id
    JOIN vulcan2xarbitrum.transaction t ON va.tx_id = t.id
    WHERE b.timestamp >= to_timestamp(c.start_date) AND b.timestamp <= to_timestamp(c.end_date)
  ),
  -- Results in the most recent vote for each poll for an address (per chain)
  distinct_mn_votes AS (
    SELECT DISTINCT ON (mnv.poll_id) *
    FROM all_valid_mainnet_votes mnv
    WHERE voter = (SELECT hot FROM dschief.all_active_vote_proxies(2147483647) WHERE cold = arg_address)
    OR voter = (SELECT cold FROM dschief.all_active_vote_proxies(2147483647) WHERE hot = arg_address)
    OR voter = arg_address
    ORDER BY poll_id DESC,
    block_id DESC
  ),
  distinct_arb_votes AS (
    SELECT DISTINCT ON (arbv.poll_id) *
    FROM all_valid_arbitrum_votes arbv
    WHERE voter = (SELECT hot FROM dschief.all_active_vote_proxies(2147483647) WHERE cold = arg_address)
    OR voter = (SELECT cold FROM dschief.all_active_vote_proxies(2147483647) WHERE hot = arg_address)
    OR voter = arg_address
    ORDER BY poll_id DESC,
    block_id DESC
  ),
  -- Results in 1 distinct vote for both chains (if exists)
  combined_votes AS (
  select * from distinct_mn_votes cv
  UNION
  select * from distinct_arb_votes cva
  )
-- Results in 1 distinct vote for only one chain (the latest vote)
SELECT DISTINCT ON (poll_id) 
  cv.poll_id,
  cv.option_id,
  cv.option_id_raw, 
  cv.block_timestamp, 
  cv.chain_id,
  -- Gets the mkr support at the end of the poll, or at current time if poll has not ended
  -- need to pass in a vote proxy address if address has a vote proxy
  polling.reverse_voter_weight(polling.unique_voter_address(arg_address, (
    select id
    from vulcan2x.block 
    where timestamp <= (SELECT LEAST (CURRENT_TIMESTAMP, cv.end_timestamp))
    order by timestamp desc limit 1)), (
    select id
    from vulcan2x.block 
    where timestamp <= (SELECT LEAST (CURRENT_TIMESTAMP, cv.end_timestamp))
    order by timestamp desc limit 1)) as amount,
  cv.hash
  FROM combined_votes cv 
  ORDER BY 
    cv.poll_id DESC, 
    cv.block_timestamp DESC
$$;


ALTER FUNCTION api.all_current_votes(arg_address character) OWNER TO "user";

--
-- Name: all_current_votes_array(character[]); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.all_current_votes_array(arg_address character[]) RETURNS TABLE(voter character varying, poll_id integer, option_id_raw character, option_id integer, block_timestamp timestamp with time zone)
    LANGUAGE sql STABLE STRICT
    AS $$
	WITH all_valid_votes AS (
		SELECT voter, option_id, option_id_raw, v.poll_id, v.block_id, b.timestamp as block_timestamp FROM polling.voted_event v
		JOIN polling.poll_created_event c ON c.poll_id=v.poll_id
		JOIN vulcan2x.block b ON v.block_id = b.id
		WHERE b.timestamp >= to_timestamp(c.start_date) AND b.timestamp <= to_timestamp(c.end_date)
	)
	SELECT DISTINCT ON (poll_id, voter) voter, poll_id, option_id_raw, option_id, block_timestamp FROM all_valid_votes
		WHERE voter = ANY (SELECT hot FROM dschief.all_active_vote_proxies(2147483647) WHERE cold = ANY (arg_address))
		OR voter = ANY (SELECT cold FROM dschief.all_active_vote_proxies(2147483647) WHERE hot = ANY (arg_address))
		OR voter = ANY (arg_address)
		ORDER BY poll_id DESC,
		voter DESC,
		block_id DESC;
$$;


ALTER FUNCTION api.all_current_votes_array(arg_address character[]) OWNER TO "user";

--
-- Name: all_delegates(); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.all_delegates() RETURNS TABLE(delegate character varying, vote_delegate character varying, block_timestamp timestamp with time zone)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT delegate, vote_delegate, b.timestamp
FROM dschief.vote_delegate_created_event d
LEFT JOIN vulcan2x.block b
ON d.block_id = b.id;
$$;


ALTER FUNCTION api.all_delegates() OWNER TO "user";

--
-- Name: all_esm_joins(); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.all_esm_joins() RETURNS TABLE(tx_from character varying, tx_hash character varying, join_amount numeric, block_timestamp timestamp with time zone)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT j.from_address, t.hash, j.join_amount, b.timestamp
FROM esm.mkr_joins j
LEFT JOIN vulcan2x.transaction t
ON j.tx_id = t.id
LEFT JOIN vulcan2x.block b
ON j.block_id = b.id;
$$;


ALTER FUNCTION api.all_esm_joins() OWNER TO "user";

--
-- Name: all_esm_v2_joins(); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.all_esm_v2_joins() RETURNS TABLE(tx_from character varying, tx_hash character varying, join_amount numeric, block_timestamp timestamp with time zone)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT j.from_address, t.hash, j.join_amount, b.timestamp
FROM esmV2.mkr_joins j
LEFT JOIN vulcan2x.transaction t
ON j.tx_id = t.id
LEFT JOIN vulcan2x.block b
ON j.block_id = b.id;
$$;


ALTER FUNCTION api.all_esm_v2_joins() OWNER TO "user";

--
-- Name: all_locks_summed(integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.all_locks_summed(unixtime_start integer, unixtime_end integer) RETURNS TABLE(from_address character varying, immediate_caller character varying, lock_amount numeric, block_number integer, block_timestamp timestamp with time zone, lock_total numeric, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
  WITH all_locks_summed AS (
    SELECT l.from_address, l.immediate_caller, l.lock, v.number, v.timestamp, sum(lock) OVER (PARTITION BY 0 ORDER BY number ASC) AS lock_total, t.hash
    FROM dschief.lock l
    INNER JOIN vulcan2x.block v ON l.block_id = v.id
    INNER JOIN vulcan2x.transaction t ON l.tx_id = t.id
    GROUP BY l.from_address, l.immediate_caller, l.lock, v.number, v.timestamp, t.hash
  )
  SELECT from_address, immediate_caller, lock, number, timestamp, lock_total, hash
  	FROM all_locks_summed
	  WHERE timestamp >= to_timestamp(unixtime_start)
    AND timestamp <= to_timestamp(unixtime_end);
$$;


ALTER FUNCTION api.all_locks_summed(unixtime_start integer, unixtime_end integer) OWNER TO "user";

--
-- Name: buggy_vote_address_mkr_weights_at_time(integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.buggy_vote_address_mkr_weights_at_time(arg_poll_id integer, arg_unix integer) RETURNS TABLE(voter character, option_id integer, option_id_raw character, mkr_support numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  select voter, option_id, option_id_raw, amount
  from polling.buggy_votes_at_time(arg_poll_id, arg_unix)
$$;


ALTER FUNCTION api.buggy_vote_address_mkr_weights_at_time(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: buggy_vote_mkr_weights_at_time_ranked_choice(integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.buggy_vote_mkr_weights_at_time_ranked_choice(arg_poll_id integer, arg_unix integer) RETURNS TABLE(option_id_raw character, mkr_support numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  select option_id_raw, amount
  from polling.buggy_votes_at_time(arg_poll_id, arg_unix)
$$;


ALTER FUNCTION api.buggy_vote_mkr_weights_at_time_ranked_choice(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: combined_chief_and_mkr_balances(integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.combined_chief_and_mkr_balances(arg_block_number integer) RETURNS TABLE(address character varying, mkr_and_chief_balance numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT m.address, COALESCE(m.balance,0) + COALESCE(d.balance,0) as mkr_and_chief_balance
	FROM mkr.holders_on_block(arg_block_number) m
	FULL OUTER JOIN dschief.balance_on_block(arg_block_number) d
	ON m.address = d.address;
$$;


ALTER FUNCTION api.combined_chief_and_mkr_balances(arg_block_number integer) OWNER TO "user";

--
-- Name: combined_chief_and_mkr_balances_at_time(integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.combined_chief_and_mkr_balances_at_time(arg_unix integer) RETURNS TABLE(address character varying, mkr_and_chief_balance numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT m.address, COALESCE(m.balance,0) + COALESCE(d.balance,0) as mkr_and_chief_balance
	FROM mkr.holders_at_time(arg_unix) m
	FULL OUTER JOIN dschief.balance_at_time(arg_unix) d
	ON m.address = d.address;
$$;


ALTER FUNCTION api.combined_chief_and_mkr_balances_at_time(arg_unix integer) OWNER TO "user";

--
-- Name: combined_chief_and_mkr_balances_currently(); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.combined_chief_and_mkr_balances_currently() RETURNS TABLE(address character varying, mkr_and_chief_balance numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT m.address, COALESCE(m.balance,0) + COALESCE(d.balance,0) as mkr_and_chief_balance
	FROM mkr.holders_currently() m
	FULL OUTER JOIN dschief.balance_currently() d
	ON m.address = d.address;
$$;


ALTER FUNCTION api.combined_chief_and_mkr_balances_currently() OWNER TO "user";

--
-- Name: current_vote(character, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.current_vote(arg_address character, arg_poll_id integer) RETURNS TABLE(option_id integer, block_id integer)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT option_id, block_id FROM polling.valid_votes(arg_poll_id)
		WHERE voter = (SELECT hot FROM dschief.all_active_vote_proxies(2147483647) WHERE cold = arg_address)
		OR voter = (SELECT cold FROM dschief.all_active_vote_proxies(2147483647) WHERE hot = arg_address)
		OR voter = arg_address
		ORDER BY block_id DESC
		LIMIT 1;
$$;


ALTER FUNCTION api.current_vote(arg_address character, arg_poll_id integer) OWNER TO "user";

--
-- Name: current_vote_ranked_choice(character, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.current_vote_ranked_choice(arg_address character, arg_poll_id integer) RETURNS TABLE(option_id_raw character, block_id integer)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT option_id_raw, block_id FROM polling.valid_votes_at_time_ranked_choice(arg_poll_id, 2147483647)
		WHERE voter = (SELECT hot FROM dschief.all_active_vote_proxies(2147483647) WHERE cold = arg_address)
		OR voter = (SELECT cold FROM dschief.all_active_vote_proxies(2147483647) WHERE hot = arg_address)
		OR voter = arg_address
		ORDER BY block_id DESC
		LIMIT 1;
$$;


ALTER FUNCTION api.current_vote_ranked_choice(arg_address character, arg_poll_id integer) OWNER TO "user";

--
-- Name: delegates(integer, public.delegate_order_by_type, public.order_direction_type, boolean, double precision, character[]); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.delegates(_first integer, order_by public.delegate_order_by_type DEFAULT 'DATE'::public.delegate_order_by_type, order_direction public.order_direction_type DEFAULT 'DESC'::public.order_direction_type, include_expired boolean DEFAULT false, seed double precision DEFAULT random(), constitutional_delegates character[] DEFAULT '{}'::bpchar[]) RETURNS SETOF public.delegate_entry
    LANGUAGE plpgsql STABLE STRICT
    AS $$
declare
  max_page_size_value int := (select api.max_page_size());
begin
  if _first > max_page_size_value then
    raise exception 'Parameter FIRST cannot be greater than %.', max_page_size_value;
  elsif seed > 1 or seed < -1 then
    raise exception 'Parameter SEED must have a value between -1 and 1';
  else
    return query
      -- Merge poll votes from Mainnet and Arbitrum and attach the timestamp to them
      with merged_vote_events as (
        select voter, vote_timestamp
        from (
          select voter, timestamp as vote_timestamp
          from polling.voted_event A
          left join vulcan2x.block B
          on A.block_id = B.id
        ) AB
        union all
        select voter, vote_timestamp
        from (
          select voter, timestamp as vote_timestamp
          from polling.voted_event_arbitrum C
          left join vulcan2xarbitrum.block D
          on C.block_id = D.id
        ) CD
      ),
      delegates_table as (
        select E.delegate, E.vote_delegate, F.timestamp as creation_date, F.timestamp + '1 year' as expiration_date, now() > F.timestamp + '1 year' as expired
        from dschief.vote_delegate_created_event E
        left join vulcan2x.block F
        on E.block_id = F.id
        -- Filter out expired delegates if include_expired is false
        where include_expired or now() < F.timestamp + '1 year'
      ),
      -- Merge delegates with their last votes
      delegates_with_last_vote as (
        select G.*, max(H.vote_timestamp) as last_voted
        from delegates_table G
        left join merged_vote_events H
        on G.vote_delegate = H.voter
        group by G.vote_delegate, G.delegate, G.creation_date, G.expiration_date, G.expired
      ),
      delegations_table as (
        select contract_address, count(immediate_caller) as delegators, sum(delegations) as delegations
        from (
          select immediate_caller, sum(lock) as delegations, contract_address
          from dschief.delegate_lock
          group by contract_address, immediate_caller
        ) as I
        where delegations > 0
        group by contract_address
      )
      select delegate::character varying(66), vote_delegate::character varying(66), creation_date, expiration_date, expired, last_voted, coalesce(delegators, 0)::int as delegator_count, coalesce(delegations, 0)::numeric(78,18) as total_mkr
      from (
        -- We call setseed here to make sure it's executed before the main select statement and the order by random clause.
        -- By appending it to the delegates_with_last_vote table and then removing the row with offset 1, we make sure the table remains unmodified.
        select setseed(seed), null delegate, null vote_delegate, null creation_date, null expiration_date, null expired, null last_voted
        union all
        select null, delegate, vote_delegate, creation_date, expiration_date, expired, last_voted from delegates_with_last_vote
        offset 1
      ) sd
      left join delegations_table
      on sd.vote_delegate::character varying(66) = delegations_table.contract_address
      order by 
        -- Ordering first by expiration: expired at the end, second by delegate type: constitutional delegates first
        -- and third by the sorting criterion selected.
        case when expired then 1 else 0 end,
        case when vote_delegate = ANY (constitutional_delegates) then 0 else 1 end,
        case
          when order_by = 'DELEGATORS' then
            case when order_direction = 'ASC' then coalesce(delegators, 0)::int else -coalesce(delegators, 0)::int end
          when order_by = 'MKR' then
            case when order_direction = 'ASC' then coalesce(delegations, 0)::numeric(78,18) else -coalesce(delegations, 0)::numeric(78,18) end
          when order_by = 'DATE' then
            case when order_direction = 'ASC' then extract(epoch from creation_date) else -extract(epoch from creation_date) end
          else
            random()
        end;
  end if;
end;
$$;


ALTER FUNCTION api.delegates(_first integer, order_by public.delegate_order_by_type, order_direction public.order_direction_type, include_expired boolean, seed double precision, constitutional_delegates character[]) OWNER TO "user";

--
-- Name: delegation_metrics(); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.delegation_metrics() RETURNS public.delegation_metrics_entry
    LANGUAGE sql STABLE STRICT
    AS $$
  select count(*) as delegator_count, sum(delegations) as total_mkr_delegated
  from (select immediate_caller, sum(lock) as delegations
  from dschief.delegate_lock
  group by immediate_caller) A
  where delegations > 0
$$;


ALTER FUNCTION api.delegation_metrics() OWNER TO "user";

--
-- Name: hot_or_cold_weight(integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.hot_or_cold_weight(arg_block_number integer) RETURNS TABLE(address character, total_weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT * FROM (SELECT hot as address, total_weight FROM dschief.total_mkr_weight_all_proxies(arg_block_number)) h
	UNION (SELECT cold, total_weight FROM dschief.total_mkr_weight_all_proxies(arg_block_number));
$$;


ALTER FUNCTION api.hot_or_cold_weight(arg_block_number integer) OWNER TO "user";

--
-- Name: hot_or_cold_weight_at_time(integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.hot_or_cold_weight_at_time(arg_unix integer) RETURNS TABLE(address character, total_weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
	WITH proxy_weights_temp AS (SELECT * FROM dschief.total_mkr_weight_all_proxies_at_time(arg_unix))
	SELECT hot as address, total_weight FROM proxy_weights_temp
	UNION (SELECT cold, total_weight FROM proxy_weights_temp);
$$;


ALTER FUNCTION api.hot_or_cold_weight_at_time(arg_unix integer) OWNER TO "user";

--
-- Name: hot_or_cold_weight_currently(); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.hot_or_cold_weight_currently() RETURNS TABLE(address character, total_weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT * FROM (SELECT hot as address, total_weight FROM dschief.total_mkr_weight_all_proxies_currently()) h
	UNION (SELECT cold, total_weight FROM dschief.total_mkr_weight_all_proxies_currently());
$$;


ALTER FUNCTION api.hot_or_cold_weight_currently() OWNER TO "user";

--
-- Name: live_poll_count(); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.live_poll_count() RETURNS bigint
    LANGUAGE sql STABLE STRICT
    AS $$
  select count(*)
  from polling.poll_created_event
  where end_date > extract(epoch from now()) and start_date <= extract(epoch from now()) and poll_id not in (
	  select poll_id
	  from polling.poll_withdrawn_event
  )
$$;


ALTER FUNCTION api.live_poll_count() OWNER TO "user";

--
-- Name: max_page_size(); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.max_page_size() RETURNS integer
    LANGUAGE sql STABLE STRICT
    AS $$
select 30
$$;


ALTER FUNCTION api.max_page_size() OWNER TO "user";

--
-- Name: mkr_delegated_to(character); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.mkr_delegated_to(arg_address character) RETURNS TABLE(from_address character varying, immediate_caller character varying, lock_amount numeric, block_number integer, block_timestamp timestamp with time zone, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
  WITH all_delegates AS (
    SELECT l.from_address, l.immediate_caller, l.lock, v.number, v.timestamp, t.hash
    FROM dschief.lock l
    INNER JOIN vulcan2x.block v ON l.block_id = v.id
    INNER JOIN vulcan2x.transaction t ON l.tx_id = t.id
    WHERE l.from_address = arg_address
    AND l.immediate_caller IN (SELECT vote_delegate FROM dschief.vote_delegate_created_event)
    GROUP BY l.from_address, l.immediate_caller, v.timestamp, l.lock, v.number, t.hash
  )
  SELECT from_address, immediate_caller, lock, number, timestamp, hash
  	FROM all_delegates
$$;


ALTER FUNCTION api.mkr_delegated_to(arg_address character) OWNER TO "user";

--
-- Name: mkr_delegated_to_v2(character); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.mkr_delegated_to_v2(arg_address character) RETURNS TABLE(from_address character varying, immediate_caller character varying, delegate_contract_address character varying, lock_amount numeric, block_number integer, block_timestamp timestamp with time zone, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
  WITH all_delegates AS (
    SELECT l.from_address, l.immediate_caller, l.lock, l.contract_address, v.number, v.timestamp, t.hash
    FROM dschief.delegate_lock l
    INNER JOIN vulcan2x.block v ON l.block_id = v.id
    INNER JOIN vulcan2x.transaction t ON l.tx_id = t.id
    WHERE l.immediate_caller = arg_address
    AND l.contract_address IN (SELECT vote_delegate FROM dschief.vote_delegate_created_event)
    GROUP BY l.from_address, l.immediate_caller, l.contract_address, v.timestamp, l.lock, v.number, t.hash
  )
  SELECT from_address, immediate_caller, contract_address, lock, number, timestamp, hash
  	FROM all_delegates
$$;


ALTER FUNCTION api.mkr_delegated_to_v2(arg_address character) OWNER TO "user";

--
-- Name: mkr_locked_delegate(character, integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.mkr_locked_delegate(arg_address character, unixtime_start integer, unixtime_end integer) RETURNS TABLE(from_address character varying, immediate_caller character varying, lock_amount numeric, block_number integer, block_timestamp timestamp with time zone, lock_total numeric, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
  WITH all_locks AS (
    SELECT l.from_address, l.immediate_caller, l.lock, v.number, v.timestamp, sum(lock) OVER (PARTITION BY 0 ORDER BY number ASC) AS lock_total, t.hash
    FROM dschief.lock l
    INNER JOIN vulcan2x.block v ON l.block_id = v.id
    INNER JOIN vulcan2x.transaction t ON l.tx_id = t.id
    WHERE l.immediate_caller = arg_address
    GROUP BY l.from_address, l.immediate_caller, l.lock, v.number, v.timestamp, t.hash
  )
  SELECT from_address, immediate_caller, lock, number, timestamp, lock_total, hash
  	FROM all_locks
	  WHERE timestamp >= to_timestamp(unixtime_start)
    AND timestamp <= to_timestamp(unixtime_end);
$$;


ALTER FUNCTION api.mkr_locked_delegate(arg_address character, unixtime_start integer, unixtime_end integer) OWNER TO "user";

--
-- Name: mkr_locked_delegate_array(character[], integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.mkr_locked_delegate_array(arg_address character[], unixtime_start integer, unixtime_end integer) RETURNS TABLE(from_address character varying, immediate_caller character varying, lock_amount numeric, block_number integer, block_timestamp timestamp with time zone, lock_total numeric, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
  WITH all_locks AS (
    SELECT l.from_address, l.immediate_caller, l.lock, v.number, v.timestamp, sum(lock) OVER (PARTITION BY 0 ORDER BY number ASC) AS lock_total, t.hash
    FROM dschief.lock l
    INNER JOIN vulcan2x.block v ON l.block_id = v.id
    INNER JOIN vulcan2x.transaction t ON l.tx_id = t.id
    WHERE l.immediate_caller = ANY (arg_address)
    GROUP BY l.from_address, l.immediate_caller, l.lock, v.number, v.timestamp, t.hash
  )
  SELECT from_address, immediate_caller, lock, number, timestamp, lock_total, hash
  	FROM all_locks
	  WHERE timestamp >= to_timestamp(unixtime_start)
    AND timestamp <= to_timestamp(unixtime_end);
$$;


ALTER FUNCTION api.mkr_locked_delegate_array(arg_address character[], unixtime_start integer, unixtime_end integer) OWNER TO "user";

--
-- Name: mkr_locked_delegate_array_totals(character[], integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.mkr_locked_delegate_array_totals(arg_address character[], unixtime_start integer, unixtime_end integer) RETURNS TABLE(from_address character varying, immediate_caller character varying, lock_amount numeric, block_number integer, block_timestamp timestamp with time zone, lock_total numeric, hash character varying, caller_lock_total numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  WITH all_locks AS (
    SELECT l.from_address, l.immediate_caller, l.lock, v.number, v.timestamp, sum(lock) OVER (PARTITION BY 0 ORDER BY number ASC) AS lock_total, t.hash, sum(lock) OVER (PARTITION BY immediate_caller ORDER BY number ASC) AS caller_lock_total
    FROM dschief.lock l
    INNER JOIN vulcan2x.block v ON l.block_id = v.id
    INNER JOIN vulcan2x.transaction t ON l.tx_id = t.id
    WHERE l.immediate_caller = ANY (arg_address)
    GROUP BY l.from_address, l.immediate_caller, l.lock, v.number, v.timestamp, t.hash
  )
  SELECT from_address, immediate_caller, lock, number, timestamp, lock_total, hash, caller_lock_total
  	FROM all_locks
	  WHERE timestamp >= to_timestamp(unixtime_start)
    AND timestamp <= to_timestamp(unixtime_end);
$$;


ALTER FUNCTION api.mkr_locked_delegate_array_totals(arg_address character[], unixtime_start integer, unixtime_end integer) OWNER TO "user";

--
-- Name: mkr_locked_delegate_array_totals_v2(character[], integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.mkr_locked_delegate_array_totals_v2(arg_address character[], unixtime_start integer, unixtime_end integer) RETURNS TABLE(from_address character varying, immediate_caller character varying, delegate_contract_address character varying, lock_amount numeric, block_number integer, block_timestamp timestamp with time zone, lock_total numeric, hash character varying, caller_lock_total numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  WITH all_locks AS (
    SELECT l.from_address, l.immediate_caller, l.contract_address, l.lock, v.number, v.timestamp, sum(lock) OVER (PARTITION BY 0 ORDER BY number ASC) AS lock_total, t.hash, sum(lock) OVER (PARTITION BY contract_address ORDER BY number ASC) AS caller_lock_total
    FROM dschief.delegate_lock l
    INNER JOIN vulcan2x.block v ON l.block_id = v.id
    INNER JOIN vulcan2x.transaction t ON l.tx_id = t.id
    WHERE l.contract_address = ANY (arg_address)
    GROUP BY l.from_address, l.immediate_caller, l.contract_address, l.lock, v.number, v.timestamp, t.hash
  )
  SELECT from_address, immediate_caller, contract_address, lock, number, timestamp, lock_total, hash, caller_lock_total
    FROM all_locks
    WHERE timestamp >= to_timestamp(unixtime_start)
    AND timestamp <= to_timestamp(unixtime_end);
$$;


ALTER FUNCTION api.mkr_locked_delegate_array_totals_v2(arg_address character[], unixtime_start integer, unixtime_end integer) OWNER TO "user";

--
-- Name: time_to_block_number(integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.time_to_block_number(arg_unix integer) RETURNS TABLE(number integer)
    LANGUAGE sql STABLE STRICT
    AS $$
  select number 
  from vulcan2x.block 
  where timestamp <= to_timestamp(arg_unix) 
  order by timestamp desc limit 1
$$;


ALTER FUNCTION api.time_to_block_number(arg_unix integer) OWNER TO "user";

--
-- Name: total_mkr_delegated_to_group(character[]); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.total_mkr_delegated_to_group(delegates character[]) RETURNS numeric
    LANGUAGE sql STABLE STRICT
    AS $$
  select sum(lock)
  from dschief.delegate_lock
  where contract_address = ANY (delegates)
$$;


ALTER FUNCTION api.total_mkr_delegated_to_group(delegates character[]) OWNER TO "user";

--
-- Name: total_mkr_weight_proxy_and_no_proxy_by_address(character, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.total_mkr_weight_proxy_and_no_proxy_by_address(arg_address character, arg_block_number integer) RETURNS TABLE(address character varying, weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT * FROM dschief.total_mkr_weight_proxy_and_no_proxy(arg_block_number)
WHERE address = arg_address;
$$;


ALTER FUNCTION api.total_mkr_weight_proxy_and_no_proxy_by_address(arg_address character, arg_block_number integer) OWNER TO "user";

--
-- Name: total_mkr_weight_proxy_and_no_proxy_by_address_at_time(character, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.total_mkr_weight_proxy_and_no_proxy_by_address_at_time(arg_address character, arg_unix integer) RETURNS TABLE(address character varying, weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT * FROM dschief.total_mkr_weight_proxy_and_no_proxy_at_time(arg_unix)
WHERE address = arg_address;
$$;


ALTER FUNCTION api.total_mkr_weight_proxy_and_no_proxy_by_address_at_time(arg_address character, arg_unix integer) OWNER TO "user";

--
-- Name: total_mkr_weight_proxy_and_no_proxy_by_address_currently(character); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.total_mkr_weight_proxy_and_no_proxy_by_address_currently(arg_address character) RETURNS TABLE(address character varying, weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT * FROM dschief.total_mkr_weight_proxy_and_no_proxy_currently()
WHERE address = arg_address;
$$;


ALTER FUNCTION api.total_mkr_weight_proxy_and_no_proxy_by_address_currently(arg_address character) OWNER TO "user";

--
-- Name: unique_voters(integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.unique_voters(arg_poll_id integer) RETURNS TABLE(unique_voters bigint)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT COUNT(DISTINCT voter) FROM
	(SELECT * FROM polling.valid_votes_at_time_ranked_choice(arg_poll_id,2147483647)
	WHERE (voter, block_id) IN (
	select voter, MAX(block_id) as block_id
	from polling.valid_votes_at_time_ranked_choice(arg_poll_id,2147483647)
	group by voter)) r
	WHERE option_id_raw != '0';
$$;


ALTER FUNCTION api.unique_voters(arg_poll_id integer) OWNER TO "user";

--
-- Name: vote_address_mkr_weights_at_time(integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.vote_address_mkr_weights_at_time(arg_poll_id integer, arg_unix integer) RETURNS TABLE(voter character, option_id integer, option_id_raw character, mkr_support numeric, chain_id integer, block_timestamp timestamp with time zone, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
  select * from polling.votes_at_time(arg_poll_id, arg_unix)
$$;


ALTER FUNCTION api.vote_address_mkr_weights_at_time(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: vote_mkr_weights_at_time_ranked_choice(integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.vote_mkr_weights_at_time_ranked_choice(arg_poll_id integer, arg_unix integer) RETURNS TABLE(option_id_raw character, mkr_support numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  select option_id_raw, amount
  from polling.votes_at_time(arg_poll_id, arg_unix)
$$;


ALTER FUNCTION api.vote_mkr_weights_at_time_ranked_choice(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: vote_option_mkr_weights(integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.vote_option_mkr_weights(arg_poll_id integer, arg_block_number integer) RETURNS TABLE(option_id integer, mkr_support numeric, block_timestamp timestamp with time zone)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT option_id, total_weight, b.timestamp FROM (SELECT option_id, SUM(weight) total_weight FROM dschief.most_recent_vote_only(arg_poll_id, arg_block_number) v
LEFT JOIN dschief.total_mkr_weight_proxy_and_no_proxy(arg_block_number)
ON voter = address
GROUP BY option_id) m
LEFT JOIN vulcan2x.block b ON b.number = arg_block_number;
$$;


ALTER FUNCTION api.vote_option_mkr_weights(arg_poll_id integer, arg_block_number integer) OWNER TO "user";

--
-- Name: vote_option_mkr_weights_at_time(integer, integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.vote_option_mkr_weights_at_time(arg_poll_id integer, arg_unix integer) RETURNS TABLE(option_id integer, mkr_support numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  select option_id, sum(amount)
  from polling.votes_at_time(arg_poll_id, arg_unix)
  group by option_id
$$;


ALTER FUNCTION api.vote_option_mkr_weights_at_time(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: vote_option_mkr_weights_currently(integer); Type: FUNCTION; Schema: api; Owner: user
--

CREATE FUNCTION api.vote_option_mkr_weights_currently(arg_poll_id integer) RETURNS TABLE(option_id integer, mkr_support numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT option_id, SUM(weight) total_weight FROM dschief.most_recent_vote_only_currently(arg_poll_id) v
LEFT JOIN dschief.total_mkr_weight_proxy_and_no_proxy_currently()
ON voter = address
GROUP BY option_id
$$;


ALTER FUNCTION api.vote_option_mkr_weights_currently(arg_poll_id integer) OWNER TO "user";

--
-- Name: all_active_vote_proxies(integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.all_active_vote_proxies(arg_block_number integer) RETURNS TABLE(hot character varying, cold character varying, proxy character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
WITH max_table AS (SELECT hot_and_cold, MAX(block_id) FROM (
	SELECT hot as hot_and_cold, block_id FROM dschief.vote_proxy_created_event
	UNION
	SELECT cold, block_id FROM dschief.vote_proxy_created_event) u
	JOIN vulcan2x.block b ON b.id = block_id
	WHERE b.number <= arg_block_number
	GROUP BY hot_and_cold)
SELECT hot, cold, vote_proxy as proxy FROM dschief.vote_proxy_created_event e
LEFT JOIN max_table as cold_max
ON cold = cold_max.hot_and_cold
LEFT JOIN max_table as hot_max
ON hot = hot_max.hot_and_cold
JOIN vulcan2x.block b ON b.id = block_id
WHERE b.number <= arg_block_number
AND block_id >= cold_max.max
AND block_id >= hot_max.max;
$$;


ALTER FUNCTION dschief.all_active_vote_proxies(arg_block_number integer) OWNER TO "user";

--
-- Name: all_active_vote_proxies_at_time(integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.all_active_vote_proxies_at_time(arg_unix integer) RETURNS TABLE(hot character varying, cold character varying, proxy character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
WITH max_table AS (SELECT hot_and_cold, MAX(block_id) FROM (
	SELECT hot as hot_and_cold, block_id FROM dschief.vote_proxy_created_event
	UNION
	SELECT cold, block_id FROM dschief.vote_proxy_created_event) u
	JOIN vulcan2x.block b ON b.id = block_id
	WHERE EXTRACT (EPOCH FROM b.timestamp) <= arg_unix
	GROUP BY hot_and_cold)
SELECT hot, cold, vote_proxy as proxy FROM dschief.vote_proxy_created_event e
LEFT JOIN max_table as cold_max
ON cold = cold_max.hot_and_cold
LEFT JOIN max_table as hot_max
ON hot = hot_max.hot_and_cold
JOIN vulcan2x.block b ON b.id = block_id
WHERE EXTRACT (EPOCH FROM b.timestamp) <= arg_unix
AND block_id >= cold_max.max
AND block_id >= hot_max.max;
$$;


ALTER FUNCTION dschief.all_active_vote_proxies_at_time(arg_unix integer) OWNER TO "user";

--
-- Name: all_active_vote_proxies_currently(); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.all_active_vote_proxies_currently() RETURNS TABLE(hot character varying, cold character varying, proxy character varying, proxy_mkr_weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT hot, cold, vote_proxy, proxy_mkr_weight
FROM dschief.vote_proxy_created_event
LEFT JOIN (SELECT address, balance as proxy_mkr_weight FROM dschief.balance_currently()) chief_table on vote_proxy = chief_table.address
WHERE proxy_mkr_weight > 0;
$$;


ALTER FUNCTION dschief.all_active_vote_proxies_currently() OWNER TO "user";

--
-- Name: all_delegates(); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.all_delegates() RETURNS TABLE(delegate character varying, vote_delegate character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT delegate, vote_delegate
FROM dschief.vote_delegate_created_event
$$;


ALTER FUNCTION dschief.all_delegates() OWNER TO "user";

--
-- Name: balance_at_time(integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.balance_at_time(arg_unix integer) RETURNS TABLE(address character varying, balance numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  	SELECT l.immediate_caller as address, SUM(l.lock) as balance
	FROM dschief.lock l 
	JOIN vulcan2x.block b ON b.id = l.block_id
	WHERE EXTRACT (EPOCH FROM b.timestamp) <= arg_unix
	GROUP BY l.immediate_caller
$$;


ALTER FUNCTION dschief.balance_at_time(arg_unix integer) OWNER TO "user";

--
-- Name: balance_currently(); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.balance_currently() RETURNS TABLE(address character varying, balance numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  	SELECT l.immediate_caller as address, SUM(l.lock) as balance
	FROM dschief.lock l 
	JOIN vulcan2x.block b ON b.id = l.block_id
	GROUP BY l.immediate_caller
$$;


ALTER FUNCTION dschief.balance_currently() OWNER TO "user";

--
-- Name: balance_on_block(integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.balance_on_block(arg_block_number integer) RETURNS TABLE(address character varying, balance numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  	SELECT l.immediate_caller as address, SUM(l.lock) as balance
	FROM dschief.lock l 
	JOIN vulcan2x.block b ON b.id = l.block_id
	WHERE b.number <= arg_block_number
	GROUP BY l.immediate_caller
$$;


ALTER FUNCTION dschief.balance_on_block(arg_block_number integer) OWNER TO "user";

--
-- Name: most_recent_vote_only(integer, integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.most_recent_vote_only(arg_poll_id integer, arg_block_number integer) RETURNS TABLE(voter character, option_id integer, block_id integer, proxy_otherwise_voter character, hot character, cold character)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT * FROM dschief.votes_with_proxy(arg_poll_id,arg_block_number)
WHERE (proxy_otherwise_voter, block_id) IN (
select proxy_otherwise_voter, MAX(block_id) as block_id
from dschief.votes_with_proxy(arg_poll_id,arg_block_number)
group by proxy_otherwise_voter);
$$;


ALTER FUNCTION dschief.most_recent_vote_only(arg_poll_id integer, arg_block_number integer) OWNER TO "user";

--
-- Name: most_recent_vote_only_at_time(integer, integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.most_recent_vote_only_at_time(arg_poll_id integer, arg_unix integer) RETURNS TABLE(voter character, option_id integer, block_id integer, proxy_otherwise_voter character, hot character, cold character)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT * FROM dschief.votes_with_proxy_at_time(arg_poll_id,arg_unix)
WHERE (proxy_otherwise_voter, block_id) IN (
select proxy_otherwise_voter, MAX(block_id) as block_id
from dschief.votes_with_proxy_at_time(arg_poll_id,arg_unix)
group by proxy_otherwise_voter);
$$;


ALTER FUNCTION dschief.most_recent_vote_only_at_time(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: most_recent_vote_only_at_time_ranked_choice(integer, integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.most_recent_vote_only_at_time_ranked_choice(arg_poll_id integer, arg_unix integer) RETURNS TABLE(voter character, option_id_raw character, block_id integer, proxy_otherwise_voter character, hot character, cold character)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT * FROM dschief.votes_with_proxy_at_time_ranked_choice(arg_poll_id,arg_unix)
WHERE (proxy_otherwise_voter, block_id) IN (
select proxy_otherwise_voter, MAX(block_id) as block_id
from dschief.votes_with_proxy_at_time_ranked_choice(arg_poll_id,arg_unix)
group by proxy_otherwise_voter);
$$;


ALTER FUNCTION dschief.most_recent_vote_only_at_time_ranked_choice(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: most_recent_vote_only_currently(integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.most_recent_vote_only_currently(arg_poll_id integer) RETURNS TABLE(voter character, option_id integer, block_id integer, proxy_otherwise_voter character, hot character, cold character)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT * FROM dschief.votes_with_proxy_currently(arg_poll_id)
WHERE (proxy_otherwise_voter, block_id) IN (
select proxy_otherwise_voter, MAX(block_id) as block_id
from dschief.votes_with_proxy_currently(arg_poll_id)
group by proxy_otherwise_voter);
$$;


ALTER FUNCTION dschief.most_recent_vote_only_currently(arg_poll_id integer) OWNER TO "user";

--
-- Name: total_mkr_weight_all_proxies(integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.total_mkr_weight_all_proxies(arg_block_number integer) RETURNS TABLE(hot character varying, cold character varying, proxy character varying, total_weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT hot, cold, proxy, COALESCE(b1,0)+COALESCE(b2,0)+COALESCE(c1,0)+COALESCE(c2,0)+COALESCE(c3,0) as total_weight
FROM dschief.all_active_vote_proxies(arg_block_number)
LEFT JOIN (SELECT address, balance as b1 FROM mkr.holders_on_block(arg_block_number)) mkr_b on hot = mkr_b.address --mkr balance in hot
LEFT JOIN (SELECT address, balance as b2 FROM mkr.holders_on_block(arg_block_number)) mkr_b1 on cold = mkr_b1.address --mkr balance in cold
LEFT JOIN (SELECT address, balance as c1 FROM dschief.balance_on_block(arg_block_number)) ch_b1 on cold = ch_b1.address -- chief balance for cold
LEFT JOIN (SELECT address, balance as c2 FROM dschief.balance_on_block(arg_block_number)) ch_b2 on hot = ch_b2.address -- chief balance for hot
LEFT JOIN (SELECT address, balance as c3 FROM dschief.balance_on_block(arg_block_number)) ch_b3 on proxy = ch_b3.address; -- chief balance for proxy
$$;


ALTER FUNCTION dschief.total_mkr_weight_all_proxies(arg_block_number integer) OWNER TO "user";

--
-- Name: total_mkr_weight_all_proxies_at_time(integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.total_mkr_weight_all_proxies_at_time(arg_unix integer) RETURNS TABLE(hot character varying, cold character varying, proxy character varying, total_weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT hot, cold, proxy, COALESCE(b1,0)+COALESCE(b2,0)+COALESCE(c1,0)+COALESCE(c2,0)+COALESCE(c3,0) as total_weight
FROM dschief.all_active_vote_proxies_at_time(arg_unix)
LEFT JOIN (SELECT address, balance as b1 FROM mkr.holders_at_time(arg_unix)) mkr_b on hot = mkr_b.address --mkr balance in hot
LEFT JOIN (SELECT address, balance as b2 FROM mkr.holders_at_time(arg_unix)) mkr_b1 on cold = mkr_b1.address --mkr balance in cold
LEFT JOIN (SELECT address, balance as c1 FROM dschief.balance_at_time(arg_unix)) ch_b1 on cold = ch_b1.address -- chief balance for cold
LEFT JOIN (SELECT address, balance as c2 FROM dschief.balance_at_time(arg_unix)) ch_b2 on hot = ch_b2.address -- chief balance for hot
LEFT JOIN (SELECT address, balance as c3 FROM dschief.balance_at_time(arg_unix)) ch_b3 on proxy = ch_b3.address; -- chief balance for proxy
$$;


ALTER FUNCTION dschief.total_mkr_weight_all_proxies_at_time(arg_unix integer) OWNER TO "user";

--
-- Name: total_mkr_weight_all_proxies_currently(); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.total_mkr_weight_all_proxies_currently() RETURNS TABLE(hot character varying, cold character varying, proxy character varying, total_weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT hot, cold, proxy, COALESCE(b1,0)+COALESCE(b2,0)+COALESCE(c1,0)+COALESCE(c2,0)+COALESCE(c3,0) as total_weight
FROM dschief.all_active_vote_proxies_currently()
LEFT JOIN (SELECT address, balance as b1 FROM mkr.holders_currently()) mkr_b on hot = mkr_b.address --mkr balance in hot
LEFT JOIN (SELECT address, balance as b2 FROM mkr.holders_currently()) mkr_b1 on cold = mkr_b1.address --mkr balance in cold
LEFT JOIN (SELECT address, balance as c1 FROM dschief.balance_currently()) ch_b1 on cold = ch_b1.address -- chief balance for cold
LEFT JOIN (SELECT address, balance as c2 FROM dschief.balance_currently()) ch_b2 on hot = ch_b2.address -- chief balance for hot
LEFT JOIN (SELECT address, balance as c3 FROM dschief.balance_currently()) ch_b3 on proxy = ch_b3.address; -- chief balance for proxy
$$;


ALTER FUNCTION dschief.total_mkr_weight_all_proxies_currently() OWNER TO "user";

--
-- Name: total_mkr_weight_proxy_and_no_proxy(integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.total_mkr_weight_proxy_and_no_proxy(arg_block_number integer) RETURNS TABLE(address character varying, weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT COALESCE(a.address, p.address) as address, COALESCE(p.total_weight,a.mkr_and_chief_balance) as weight FROM api.hot_or_cold_weight(arg_block_number) p
FULL OUTER JOIN api.combined_chief_and_mkr_balances(arg_block_number) a
ON p.address = a.address;
$$;


ALTER FUNCTION dschief.total_mkr_weight_proxy_and_no_proxy(arg_block_number integer) OWNER TO "user";

--
-- Name: total_mkr_weight_proxy_and_no_proxy_at_time(integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.total_mkr_weight_proxy_and_no_proxy_at_time(arg_unix integer) RETURNS TABLE(address character varying, weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
	WITH mkr_balances_temp AS (SELECT * FROM mkr.holders_at_time(arg_unix)),
	chief_balances_temp AS (SELECT * FROM dschief.balance_at_time(arg_unix)),
	total_mkr_weight_all_proxies_temp AS (
		SELECT hot, cold, proxy, COALESCE(b1,0)+COALESCE(b2,0)+COALESCE(c1,0)+COALESCE(c2,0)+COALESCE(c3,0) as total_weight
		FROM dschief.all_active_vote_proxies_at_time(arg_unix)
		LEFT JOIN (SELECT address, balance as b1 FROM mkr_balances_temp) mkr_b on hot = mkr_b.address --mkr balance in hot
		LEFT JOIN (SELECT address, balance as b2 FROM mkr_balances_temp) mkr_b1 on cold = mkr_b1.address --mkr balance in cold
		LEFT JOIN (SELECT address, balance as c1 FROM chief_balances_temp) ch_b1 on cold = ch_b1.address -- chief balance for cold
		LEFT JOIN (SELECT address, balance as c2 FROM chief_balances_temp) ch_b2 on hot = ch_b2.address -- chief balance for hot
		LEFT JOIN (SELECT address, balance as c3 FROM chief_balances_temp) ch_b3 on proxy = ch_b3.address -- chief balance for proxy)
	),
	hot_or_cold_temp AS (
		SELECT hot as address, total_weight FROM total_mkr_weight_all_proxies_temp
		UNION (SELECT cold, total_weight FROM total_mkr_weight_all_proxies_temp)
	),
	combined_chief_and_mkr_temp AS
		(SELECT m.address, COALESCE(m.balance,0) + COALESCE(d.balance,0) as mkr_and_chief_balance
		FROM mkr_balances_temp m
		FULL OUTER JOIN chief_balances_temp d
		ON m.address = d.address
	)
	SELECT COALESCE(a.address, p.address) as address, COALESCE(p.total_weight,a.mkr_and_chief_balance) as weight FROM hot_or_cold_temp p
	FULL OUTER JOIN combined_chief_and_mkr_temp a
	ON p.address = a.address;
$$;


ALTER FUNCTION dschief.total_mkr_weight_proxy_and_no_proxy_at_time(arg_unix integer) OWNER TO "user";

--
-- Name: total_mkr_weight_proxy_and_no_proxy_currently(); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.total_mkr_weight_proxy_and_no_proxy_currently() RETURNS TABLE(address character varying, weight numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT COALESCE(a.address, p.address) as address, COALESCE(p.total_weight,a.mkr_and_chief_balance) as weight FROM api.hot_or_cold_weight_currently() p
FULL OUTER JOIN api.combined_chief_and_mkr_balances_currently() a
ON p.address = a.address;
$$;


ALTER FUNCTION dschief.total_mkr_weight_proxy_and_no_proxy_currently() OWNER TO "user";

--
-- Name: votes_with_proxy(integer, integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.votes_with_proxy(arg_poll_id integer, arg_block_number integer) RETURNS TABLE(voter character, option_id integer, block_id integer, proxy_otherwise_voter character, hot character, cold character)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT voter, option_id, block_id, COALESCE(proxy, voter) as proxy_otherwise_voter, hot, cold FROM polling.valid_votes_before_block(arg_poll_id, arg_block_number)
	LEFT JOIN dschief.all_active_vote_proxies(arg_block_number)
	ON voter = hot OR voter = cold;
$$;


ALTER FUNCTION dschief.votes_with_proxy(arg_poll_id integer, arg_block_number integer) OWNER TO "user";

--
-- Name: votes_with_proxy_at_time(integer, integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.votes_with_proxy_at_time(arg_poll_id integer, arg_unix integer) RETURNS TABLE(voter character, option_id integer, block_id integer, proxy_otherwise_voter character, hot character, cold character)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT voter, option_id, block_id, COALESCE(proxy, voter) as proxy_otherwise_voter, hot, cold FROM polling.valid_votes_at_time(arg_poll_id, arg_unix)
	LEFT JOIN dschief.all_active_vote_proxies_at_time(arg_unix)
	ON voter = hot OR voter = cold;
$$;


ALTER FUNCTION dschief.votes_with_proxy_at_time(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: votes_with_proxy_at_time_ranked_choice(integer, integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.votes_with_proxy_at_time_ranked_choice(arg_poll_id integer, arg_unix integer) RETURNS TABLE(voter character, option_id_raw character, block_id integer, proxy_otherwise_voter character, hot character, cold character)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT voter, option_id_raw, block_id, COALESCE(proxy, voter) as proxy_otherwise_voter, hot, cold FROM polling.valid_votes_at_time_ranked_choice(arg_poll_id, arg_unix)
	LEFT JOIN dschief.all_active_vote_proxies_at_time(arg_unix)
	ON voter = hot OR voter = cold;
$$;


ALTER FUNCTION dschief.votes_with_proxy_at_time_ranked_choice(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: votes_with_proxy_currently(integer); Type: FUNCTION; Schema: dschief; Owner: user
--

CREATE FUNCTION dschief.votes_with_proxy_currently(arg_poll_id integer) RETURNS TABLE(voter character, option_id integer, block_id integer, proxy_otherwise_voter character, hot character, cold character)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT voter, option_id, block_id, COALESCE(proxy, voter) as proxy_otherwise_voter, hot, cold FROM polling.valid_votes_currently(arg_poll_id)
	LEFT JOIN dschief.all_active_vote_proxies_currently()
	ON voter = hot OR voter = cold;
$$;


ALTER FUNCTION dschief.votes_with_proxy_currently(arg_poll_id integer) OWNER TO "user";

--
-- Name: holders_at_time(integer); Type: FUNCTION; Schema: mkr; Owner: user
--

CREATE FUNCTION mkr.holders_at_time(arg_unix integer) RETURNS TABLE(address character varying, balance numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT SUMS.address, COALESCE(SUMS.sum, 0) + COALESCE(SUBS.sum, 0) as balance FROM (
SELECT t.receiver as address, SUM(t.amount) FROM mkr.transfer_event t
WHERE t.block_id <= (select max(id) from vulcan2x.block b where EXTRACT (EPOCH FROM b.timestamp) <= arg_unix)
GROUP BY t.receiver
) SUMS
LEFT JOIN (
SELECT sender as address, SUM(-t.amount) FROM mkr.transfer_event t 
WHERE t.block_id <= (select max(id) from vulcan2x.block b where EXTRACT (EPOCH FROM b.timestamp) <= arg_unix)
GROUP BY t.sender
) SUBS ON (SUMS.address = SUBS.address);
$$;


ALTER FUNCTION mkr.holders_at_time(arg_unix integer) OWNER TO "user";

--
-- Name: holders_currently(); Type: FUNCTION; Schema: mkr; Owner: user
--

CREATE FUNCTION mkr.holders_currently() RETURNS TABLE(address character varying, balance numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT SUMS.address, COALESCE(SUMS.sum, 0) + COALESCE(SUBS.sum, 0) as balance FROM (
SELECT t.receiver as address, SUM(t.amount) FROM mkr.transfer_event t
GROUP BY t.receiver
) SUMS
LEFT JOIN (
SELECT sender as address, SUM(-t.amount) FROM mkr.transfer_event t 
GROUP BY t.sender
) SUBS ON (SUMS.address = SUBS.address);
$$;


ALTER FUNCTION mkr.holders_currently() OWNER TO "user";

--
-- Name: holders_on_block(integer); Type: FUNCTION; Schema: mkr; Owner: user
--

CREATE FUNCTION mkr.holders_on_block(arg_block_number integer) RETURNS TABLE(address character varying, balance numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
SELECT SUMS.address, COALESCE(SUMS.sum, 0) + COALESCE(SUBS.sum, 0) as balance FROM (
SELECT t.receiver as address, SUM(t.amount) FROM mkr.transfer_event t
WHERE t.block_id <= (select max(id) from vulcan2x.block b where b.number <= arg_block_number)
GROUP BY t.receiver
) SUMS
LEFT JOIN (
SELECT sender as address, SUM(-t.amount) FROM mkr.transfer_event t 
WHERE t.block_id <= (select max(id) from vulcan2x.block b where b.number <= arg_block_number)
GROUP BY t.sender
) SUBS ON (SUMS.address = SUBS.address);
$$;


ALTER FUNCTION mkr.holders_on_block(arg_block_number integer) OWNER TO "user";

--
-- Name: buggy_reverse_voter_weight(character, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.buggy_reverse_voter_weight(address character, block_id integer) RETURNS numeric
    LANGUAGE plpgsql STABLE STRICT
    AS $$
declare
  wallet_amount decimal(78,18);
  chief_amount decimal(78,18);
  proxy dschief.vote_proxy_created_event%rowtype;
  hot_wallet_amount decimal(78,18);
  cold_wallet_amount decimal(78,18);
begin
  select amount into wallet_amount from mkr.balances ba
  where ba.address = buggy_reverse_voter_weight.address
  and ba.block_id <= buggy_reverse_voter_weight.block_id
  order by ba.id desc limit 1;

  select amount into chief_amount from dschief.balances ba
  where ba.address = buggy_reverse_voter_weight.address
  and ba.block_id <= buggy_reverse_voter_weight.block_id
  order by ba.id desc limit 1;

  -- if address is a proxy, add balances for hot & cold wallets

  select * into proxy
  from dschief.vote_proxy_created_event vpc
  where vote_proxy = buggy_reverse_voter_weight.address
  and vpc.block_id <= buggy_reverse_voter_weight.block_id
  order by vpc.id desc limit 1;

  if proxy is not null then
    select amount into hot_wallet_amount from mkr.balances ba
    where ba.address = proxy.hot
    and ba.block_id <= buggy_reverse_voter_weight.block_id
    order by ba.id desc limit 1;

    select amount into cold_wallet_amount from mkr.balances ba
    where ba.address = proxy.cold
    and ba.block_id <= buggy_reverse_voter_weight.block_id
    order by ba.id desc limit 1;
  end if;

  return coalesce(wallet_amount, 0) + 
    coalesce(chief_amount, 0) + 
    coalesce(hot_wallet_amount, 0) +
    coalesce(cold_wallet_amount, 0);
end;
$$;


ALTER FUNCTION polling.buggy_reverse_voter_weight(address character, block_id integer) OWNER TO "user";

--
-- Name: buggy_votes(integer, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.buggy_votes(poll_id integer, block_id integer) RETURNS TABLE(voter character, option_id integer, option_id_raw character, amount numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  select 
    voter,
    option_id, 
    option_id_raw,
    polling.buggy_reverse_voter_weight(voter, buggy_votes.block_id)
  from polling.unique_votes(buggy_votes.poll_id) vv
  where vv.block_id <= buggy_votes.block_id
$$;


ALTER FUNCTION polling.buggy_votes(poll_id integer, block_id integer) OWNER TO "user";

--
-- Name: buggy_votes_at_time(integer, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.buggy_votes_at_time(poll_id integer, unixtime integer) RETURNS TABLE(voter character, option_id integer, option_id_raw character, amount numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  select * from polling.buggy_votes(poll_id, (
    select id from vulcan2x.block where timestamp <= to_timestamp(unixtime)
    order by timestamp desc limit 1
  )) 
$$;


ALTER FUNCTION polling.buggy_votes_at_time(poll_id integer, unixtime integer) OWNER TO "user";

--
-- Name: reverse_voter_weight(character, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.reverse_voter_weight(address character, block_id integer) RETURNS numeric
    LANGUAGE plpgsql STABLE STRICT
    AS $$
declare
  wallet_amount decimal(78,18);
  chief_amount decimal(78,18);
  proxy dschief.vote_proxy_created_event%rowtype;
  hot_wallet_amount decimal(78,18);
  cold_wallet_amount decimal(78,18);
  hot_chief_amount decimal(78,18);
  cold_chief_amount decimal(78,18);
begin
  select amount into wallet_amount from mkr.balances ba
  where ba.address = reverse_voter_weight.address
  and ba.block_id <= reverse_voter_weight.block_id
  order by ba.id desc limit 1;

  select amount into chief_amount from dschief.balances ba
  where ba.address = reverse_voter_weight.address
  and ba.block_id <= reverse_voter_weight.block_id
  order by ba.id desc limit 1;

  -- if address is a proxy, add balances for hot & cold wallets

  select * into proxy
  from dschief.vote_proxy_created_event vpc
  where vote_proxy = reverse_voter_weight.address
  and vpc.block_id <= reverse_voter_weight.block_id
  order by vpc.id desc limit 1;

  if proxy is not null then
    select amount into hot_wallet_amount from mkr.balances ba
    where ba.address = proxy.hot
    and ba.block_id <= reverse_voter_weight.block_id
    order by ba.id desc limit 1;

    select amount into hot_chief_amount from dschief.balances ba
    where ba.address = proxy.hot
    and ba.block_id <= reverse_voter_weight.block_id
    order by ba.id desc limit 1;

    if proxy.hot != proxy.cold then
      select amount into cold_wallet_amount from mkr.balances ba
      where ba.address = proxy.cold
      and ba.block_id <= reverse_voter_weight.block_id
      order by ba.id desc limit 1;

      select amount into cold_chief_amount from dschief.balances ba
      where ba.address = proxy.cold
      and ba.block_id <= reverse_voter_weight.block_id
      order by ba.id desc limit 1;
    end if;
  end if;

  return coalesce(wallet_amount, 0) + 
    coalesce(chief_amount, 0) + 
    coalesce(hot_wallet_amount, 0) +
    coalesce(cold_wallet_amount, 0) +
    coalesce(hot_chief_amount, 0) +
    coalesce(cold_chief_amount, 0);
end;
$$;


ALTER FUNCTION polling.reverse_voter_weight(address character, block_id integer) OWNER TO "user";

--
-- Name: unique_voter_address(character); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.unique_voter_address(address character) RETURNS character
    LANGUAGE sql STABLE STRICT
    AS $$
  select coalesce(
    (
      select vote_proxy from dschief.vote_proxy_created_event 
      where address in (hot, cold)
      order by id desc limit 1
    ),
    address
  )
$$;


ALTER FUNCTION polling.unique_voter_address(address character) OWNER TO "user";

--
-- Name: unique_voter_address(character, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.unique_voter_address(address character, arg_block_id integer) RETURNS character
    LANGUAGE plpgsql STABLE STRICT
    AS $$
  declare
    proxy dschief.vote_proxy_created_event%rowtype;
    linked_proxy dschief.vote_proxy_created_event%rowtype;
  begin
      select * into proxy from dschief.vote_proxy_created_event 
      where address in (hot, cold)
      and block_id <= arg_block_id
      order by id desc limit 1;

      -- if linked address has a more recent vote proxy, then proxy is not valid
      if proxy is not null then
        if address = proxy.hot then
          select * into linked_proxy from dschief.vote_proxy_created_event 
          where proxy.cold in (hot, cold)
          and block_id <= arg_block_id
          order by id desc limit 1;
        end if;

        if address = proxy.cold then
          select * into linked_proxy from dschief.vote_proxy_created_event 
          where proxy.hot in (hot, cold)
          and block_id <= arg_block_id
          order by id desc limit 1;
        end if;

        if linked_proxy is not null and linked_proxy.block_id > proxy.block_id then
          return address;
        end if;
      end if;

    return coalesce(proxy.vote_proxy,address);
  end;
$$;


ALTER FUNCTION polling.unique_voter_address(address character, arg_block_id integer) OWNER TO "user";

--
-- Name: unique_votes(integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.unique_votes(arg_poll_id integer) RETURNS TABLE(voter character, option_id integer, option_id_raw character, block_id integer)
    LANGUAGE sql STABLE STRICT
    AS $$
  select address, option_id, option_id_raw, block_id from (
    -- middle query removes duplicates by unique address
    select 
      address,
      option_id,
      option_id_raw,
      block_id,
      row_number() over (partition by address order by block_id desc) rownum from (
      -- innermost query looks up unique address
      select
        polling.unique_voter_address(voter) address, 
        option_id, 
        option_id_raw, 
        v.block_id
      from polling.voted_event v
      join polling.poll_created_event c on c.poll_id = v.poll_id
      join vulcan2x.block b on v.block_id = b.id
      where v.poll_id = arg_poll_id 
      and b.timestamp between to_timestamp(c.start_date) and to_timestamp(c.end_date)
    ) sub2
  ) sub1
  where rownum = 1;
$$;


ALTER FUNCTION polling.unique_votes(arg_poll_id integer) OWNER TO "user";

--
-- Name: unique_votes(integer, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.unique_votes(arg_poll_id integer, arg_block_id integer) RETURNS TABLE(voter character, option_id integer, option_id_raw character, block_id integer)
    LANGUAGE sql STABLE STRICT
    AS $$
  select address, option_id, option_id_raw, block_id from (
    -- middle query removes duplicates by unique address
    select 
      address,
      option_id,
      option_id_raw,
      block_id,
      row_number() over (partition by address order by block_id desc) rownum from (
      -- innermost query looks up unique address
      select
        polling.unique_voter_address(voter, arg_block_id) address, 
        option_id, 
        option_id_raw, 
        v.block_id
      from polling.voted_event v
      join polling.poll_created_event c on c.poll_id = v.poll_id
      join vulcan2x.block b on v.block_id = b.id
      where v.poll_id = arg_poll_id 
      and b.timestamp between to_timestamp(c.start_date) and to_timestamp(c.end_date)
    ) sub2
  ) sub1
  where rownum = 1;
$$;


ALTER FUNCTION polling.unique_votes(arg_poll_id integer, arg_block_id integer) OWNER TO "user";

--
-- Name: valid_votes(integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.valid_votes(arg_poll_id integer) RETURNS TABLE(voter character varying, option_id integer, block_id integer)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT voter, option_id, v.block_id FROM polling.voted_event v
	JOIN polling.poll_created_event c ON c.poll_id=v.poll_id
	JOIN vulcan2x.block b ON v.block_id = b.id
	WHERE v.poll_id = arg_poll_id AND b.timestamp >= to_timestamp(c.start_date) AND b.timestamp <= to_timestamp(c.end_date);
$$;


ALTER FUNCTION polling.valid_votes(arg_poll_id integer) OWNER TO "user";

--
-- Name: valid_votes_at_time(integer, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.valid_votes_at_time(arg_poll_id integer, arg_unix integer) RETURNS TABLE(voter character varying, option_id integer, block_id integer)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT voter, option_id, v.block_id FROM polling.voted_event v
	JOIN polling.poll_created_event c ON c.poll_id=v.poll_id
	JOIN vulcan2x.block b ON v.block_id = b.id
	WHERE EXTRACT (EPOCH FROM b.timestamp) <= arg_unix AND v.poll_id = arg_poll_id AND b.timestamp >= to_timestamp(c.start_date) AND b.timestamp <= to_timestamp(c.end_date);
$$;


ALTER FUNCTION polling.valid_votes_at_time(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: valid_votes_at_time_ranked_choice(integer, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.valid_votes_at_time_ranked_choice(arg_poll_id integer, arg_unix integer) RETURNS TABLE(voter character varying, option_id_raw character, block_id integer)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT voter, option_id_raw, v.block_id FROM polling.voted_event v
	JOIN polling.poll_created_event c ON c.poll_id=v.poll_id
	JOIN vulcan2x.block b ON v.block_id = b.id
	WHERE EXTRACT (EPOCH FROM b.timestamp) <= arg_unix AND v.poll_id = arg_poll_id AND b.timestamp >= to_timestamp(c.start_date) AND b.timestamp <= to_timestamp(c.end_date);
$$;


ALTER FUNCTION polling.valid_votes_at_time_ranked_choice(arg_poll_id integer, arg_unix integer) OWNER TO "user";

--
-- Name: valid_votes_before_block(integer, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.valid_votes_before_block(arg_poll_id integer, arg_block_number integer) RETURNS TABLE(voter character varying, option_id integer, block_id integer)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT voter, option_id, v.block_id FROM polling.voted_event v
	JOIN polling.poll_created_event c ON c.poll_id=v.poll_id
	JOIN vulcan2x.block b ON v.block_id = b.id
	WHERE b.number <= arg_block_number AND v.poll_id = arg_poll_id AND b.timestamp >= to_timestamp(c.start_date) AND b.timestamp <= to_timestamp(c.end_date);
$$;


ALTER FUNCTION polling.valid_votes_before_block(arg_poll_id integer, arg_block_number integer) OWNER TO "user";

--
-- Name: valid_votes_currently(integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.valid_votes_currently(arg_poll_id integer) RETURNS TABLE(voter character varying, option_id integer, block_id integer)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT voter, option_id, v.block_id FROM polling.voted_event v
	JOIN polling.poll_created_event c ON c.poll_id=v.poll_id
	JOIN vulcan2x.block b ON v.block_id = b.id
	WHERE v.poll_id = arg_poll_id AND b.timestamp >= to_timestamp(c.start_date) AND b.timestamp <= to_timestamp(c.end_date);
$$;


ALTER FUNCTION polling.valid_votes_currently(arg_poll_id integer) OWNER TO "user";

--
-- Name: voter_weight(character, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.voter_weight(address character, block_id integer) RETURNS numeric
    LANGUAGE plpgsql STABLE STRICT
    AS $$
declare
  wallet_amount decimal(78,18);
  chief_amount decimal(78,18);
  proxy dschief.vote_proxy_created_event%rowtype;
  proxy_chief_amount decimal(78,18);
  linked_wallet_amount decimal(78,18);
begin
  select amount into wallet_amount from mkr.balances ba
  where ba.address = voter_weight.address
  and ba.block_id <= voter_weight.block_id
  order by ba.id desc limit 1;

  select amount into chief_amount from dschief.balances ba
  where ba.address = voter_weight.address
  and ba.block_id <= voter_weight.block_id
  order by ba.id desc limit 1;

  select * into proxy
  from dschief.vote_proxy_created_event vpc
  where (hot = voter_weight.address or cold = voter_weight.address)
  and vpc.block_id <= voter_weight.block_id
  order by vpc.id desc limit 1;

  if proxy is not null then
    select amount into proxy_chief_amount from dschief.balances ba
    where ba.address = proxy.vote_proxy
    and ba.block_id <= voter_weight.block_id
    order by ba.id desc limit 1;

    select amount into linked_wallet_amount from mkr.balances ba
    where ba.address = (
      case when proxy.cold = voter_weight.address
      then proxy.hot else proxy.cold end)
    and ba.block_id <= voter_weight.block_id
    order by ba.id desc limit 1;
  end if;

  return coalesce(wallet_amount, 0) + 
    coalesce(chief_amount, 0) + 
    coalesce(proxy_chief_amount, 0) + 
    coalesce(linked_wallet_amount, 0);
end;
$$;


ALTER FUNCTION polling.voter_weight(address character, block_id integer) OWNER TO "user";

--
-- Name: votes(integer, integer, timestamp with time zone); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.votes(poll_id integer, block_id integer, poll_end_timestamp timestamp with time zone) RETURNS TABLE(voter character, option_id integer, option_id_raw character, amount numeric, chain_id integer, block_timestamp timestamp with time zone, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
  select 
    voter,
    option_id,
    option_id_raw,
    polling.reverse_voter_weight(voter, votes.block_id),
    chain_id,
    block_timestamp,
    hash
    	from unique_votes(votes.poll_id, votes.block_id) vv 
    	where vv.block_timestamp <= poll_end_timestamp -- get the unique vote that is LTE to the poll end timestamp
$$;


ALTER FUNCTION polling.votes(poll_id integer, block_id integer, poll_end_timestamp timestamp with time zone) OWNER TO "user";

--
-- Name: votes_at_block(integer, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.votes_at_block(poll_id integer, block_number integer) RETURNS TABLE(voter character, option_id integer, option_id_raw character, amount numeric)
    LANGUAGE sql STABLE STRICT
    AS $$
  select * from polling.votes(poll_id, (
    select id from vulcan2x.block where number = block_number
  )) 
$$;


ALTER FUNCTION polling.votes_at_block(poll_id integer, block_number integer) OWNER TO "user";

--
-- Name: votes_at_time(integer, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.votes_at_time(poll_id integer, unixtime integer) RETURNS TABLE(voter character, option_id integer, option_id_raw character, amount numeric, chain_id integer, block_timestamp timestamp with time zone, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
  select * from polling.votes(poll_id, (
    -- get the L1 block at the endtime timestamp, or nearest one below it
    select id from vulcan2x.block where timestamp <= to_timestamp(unixtime)
    order by timestamp desc limit 1
  ), to_timestamp(unixtime))
$$;


ALTER FUNCTION polling.votes_at_time(poll_id integer, unixtime integer) OWNER TO "user";

--
-- Name: notify_watchers_ddl(); Type: FUNCTION; Schema: postgraphile_watch; Owner: user
--

CREATE FUNCTION postgraphile_watch.notify_watchers_ddl() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform pg_notify(
    'postgraphile_watch',
    json_build_object(
      'type',
      'ddl',
      'payload',
      (select json_agg(json_build_object('schema', schema_name, 'command', command_tag)) from pg_event_trigger_ddl_commands() as x)
    )::text
  );
end;
$$;


ALTER FUNCTION postgraphile_watch.notify_watchers_ddl() OWNER TO "user";

--
-- Name: notify_watchers_drop(); Type: FUNCTION; Schema: postgraphile_watch; Owner: user
--

CREATE FUNCTION postgraphile_watch.notify_watchers_drop() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
begin
  perform pg_notify(
    'postgraphile_watch',
    json_build_object(
      'type',
      'drop',
      'payload',
      (select json_agg(distinct x.schema_name) from pg_event_trigger_dropped_objects() as x)
    )::text
  );
end;
$$;


ALTER FUNCTION postgraphile_watch.notify_watchers_drop() OWNER TO "user";

--
-- Name: unique_votes(integer, integer); Type: FUNCTION; Schema: public; Owner: user
--

CREATE FUNCTION public.unique_votes(arg_poll_id integer, arg_proxy_block_id_mn integer) RETURNS TABLE(voter character, option_id integer, option_id_raw character, block_id integer, chain_id integer, block_timestamp timestamp with time zone, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
  select address, option_id, option_id_raw, block_id, chain_id, block_timestamp, hash
  from (
    -- middle query removes duplicates by unique address
    select 
      address,
      option_id,
      option_id_raw,
      block_id,
      chain_id,
      block_timestamp,
      hash,
      row_number() over (partition by address order by block_timestamp desc) rownum from (
      -- innermost query looks up unique address
      select
      	address address,
        option_id,
        option_id_raw, 
        v.block_id,
        v.chain_id,
        v.block_timestamp,
        v.hash
      from voted_events_merged(arg_proxy_block_id_mn) v
      join polling.poll_created_event c on c.poll_id = v.poll_id
      where v.poll_id = arg_poll_id 
      and v.block_timestamp between to_timestamp(c.start_date) and to_timestamp(c.end_date)
    ) sub2
  ) sub1
  where rownum = 1;
$$;


ALTER FUNCTION public.unique_votes(arg_poll_id integer, arg_proxy_block_id_mn integer) OWNER TO "user";

--
-- Name: voted_events_merged(integer); Type: FUNCTION; Schema: public; Owner: user
--

CREATE FUNCTION public.voted_events_merged(arg_proxy_block_id_mn integer) RETURNS TABLE(poll_id integer, address character, option_id integer, option_id_raw character varying, block_id integer, chain_id integer, block_timestamp timestamp with time zone, hash character varying)
    LANGUAGE sql STABLE STRICT
    AS $$
	SELECT DISTINCT (poll_id) poll_id, address, option_id, option_id_raw, block_id, chain_id, timestamp, hash 
    FROM (
		SELECT polling.unique_voter_address(voter, arg_proxy_block_id_mn) address, option_id, option_id_raw, ve.block_id, poll_id, chain_id, b.timestamp, tx.hash
		FROM polling.voted_event ve
		JOIN vulcan2x.block b ON ve.block_id = b.id
		JOIN vulcan2x.transaction tx ON ve.tx_id = tx.id
			UNION
		SELECT polling.unique_voter_address(voter, arg_proxy_block_id_mn) address, option_id, option_id_raw, vea.block_id, poll_id, chain_id, ba.timestamp, txa.hash
		FROM polling.voted_event_arbitrum vea
		JOIN vulcan2xarbitrum.block ba ON vea.block_id = ba.id
		JOIN vulcan2xarbitrum.transaction txa ON vea.tx_id = txa.id
		) sub1
$$;


ALTER FUNCTION public.voted_events_merged(arg_proxy_block_id_mn integer) OWNER TO "user";

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: chain; Type: TABLE; Schema: chains; Owner: user
--

CREATE TABLE chains.chain (
    id integer NOT NULL,
    chain_id integer NOT NULL,
    name character varying(66) NOT NULL
);


ALTER TABLE chains.chain OWNER TO "user";

--
-- Name: chain_id_seq; Type: SEQUENCE; Schema: chains; Owner: user
--

CREATE SEQUENCE chains.chain_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE chains.chain_id_seq OWNER TO "user";

--
-- Name: chain_id_seq; Type: SEQUENCE OWNED BY; Schema: chains; Owner: user
--

ALTER SEQUENCE chains.chain_id_seq OWNED BY chains.chain.id;


--
-- Name: balances; Type: TABLE; Schema: dschief; Owner: user
--

CREATE TABLE dschief.balances (
    id integer NOT NULL,
    address character(66) NOT NULL,
    amount numeric(78,18) NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE dschief.balances OWNER TO "user";

--
-- Name: balances_id_seq; Type: SEQUENCE; Schema: dschief; Owner: user
--

CREATE SEQUENCE dschief.balances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dschief.balances_id_seq OWNER TO "user";

--
-- Name: balances_id_seq; Type: SEQUENCE OWNED BY; Schema: dschief; Owner: user
--

ALTER SEQUENCE dschief.balances_id_seq OWNED BY dschief.balances.id;


--
-- Name: delegate_lock; Type: TABLE; Schema: dschief; Owner: user
--

CREATE TABLE dschief.delegate_lock (
    id integer NOT NULL,
    from_address character varying(66) NOT NULL,
    immediate_caller character varying(66) NOT NULL,
    lock numeric(78,18) NOT NULL,
    contract_address character varying(66) NOT NULL,
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE dschief.delegate_lock OWNER TO "user";

--
-- Name: delegate_lock_id_seq; Type: SEQUENCE; Schema: dschief; Owner: user
--

CREATE SEQUENCE dschief.delegate_lock_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dschief.delegate_lock_id_seq OWNER TO "user";

--
-- Name: delegate_lock_id_seq; Type: SEQUENCE OWNED BY; Schema: dschief; Owner: user
--

ALTER SEQUENCE dschief.delegate_lock_id_seq OWNED BY dschief.delegate_lock.id;


--
-- Name: lock; Type: TABLE; Schema: dschief; Owner: user
--

CREATE TABLE dschief.lock (
    id integer NOT NULL,
    from_address character varying(66) NOT NULL,
    immediate_caller character varying(66) NOT NULL,
    lock numeric(78,18) NOT NULL,
    contract_address character varying(66) NOT NULL,
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE dschief.lock OWNER TO "user";

--
-- Name: lock_id_seq; Type: SEQUENCE; Schema: dschief; Owner: user
--

CREATE SEQUENCE dschief.lock_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dschief.lock_id_seq OWNER TO "user";

--
-- Name: lock_id_seq; Type: SEQUENCE OWNED BY; Schema: dschief; Owner: user
--

ALTER SEQUENCE dschief.lock_id_seq OWNED BY dschief.lock.id;


--
-- Name: vote_delegate_created_event; Type: TABLE; Schema: dschief; Owner: user
--

CREATE TABLE dschief.vote_delegate_created_event (
    id integer NOT NULL,
    delegate character varying(66) NOT NULL,
    vote_delegate character varying(66) NOT NULL,
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE dschief.vote_delegate_created_event OWNER TO "user";

--
-- Name: vote_delegate_created_event_id_seq; Type: SEQUENCE; Schema: dschief; Owner: user
--

CREATE SEQUENCE dschief.vote_delegate_created_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dschief.vote_delegate_created_event_id_seq OWNER TO "user";

--
-- Name: vote_delegate_created_event_id_seq; Type: SEQUENCE OWNED BY; Schema: dschief; Owner: user
--

ALTER SEQUENCE dschief.vote_delegate_created_event_id_seq OWNED BY dschief.vote_delegate_created_event.id;


--
-- Name: vote_proxy_created_event; Type: TABLE; Schema: dschief; Owner: user
--

CREATE TABLE dschief.vote_proxy_created_event (
    id integer NOT NULL,
    cold character varying(66) NOT NULL,
    hot character varying(66) NOT NULL,
    vote_proxy character varying(66) NOT NULL,
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE dschief.vote_proxy_created_event OWNER TO "user";

--
-- Name: vote_proxy_created_event_id_seq; Type: SEQUENCE; Schema: dschief; Owner: user
--

CREATE SEQUENCE dschief.vote_proxy_created_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE dschief.vote_proxy_created_event_id_seq OWNER TO "user";

--
-- Name: vote_proxy_created_event_id_seq; Type: SEQUENCE OWNED BY; Schema: dschief; Owner: user
--

ALTER SEQUENCE dschief.vote_proxy_created_event_id_seq OWNED BY dschief.vote_proxy_created_event.id;


--
-- Name: mkr_joins; Type: TABLE; Schema: esm; Owner: user
--

CREATE TABLE esm.mkr_joins (
    id integer NOT NULL,
    from_address character varying(66) NOT NULL,
    immediate_caller character varying(66) NOT NULL,
    join_amount numeric(78,18) NOT NULL,
    contract_address character varying(66) NOT NULL,
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE esm.mkr_joins OWNER TO "user";

--
-- Name: mkr_joins_id_seq; Type: SEQUENCE; Schema: esm; Owner: user
--

CREATE SEQUENCE esm.mkr_joins_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE esm.mkr_joins_id_seq OWNER TO "user";

--
-- Name: mkr_joins_id_seq; Type: SEQUENCE OWNED BY; Schema: esm; Owner: user
--

ALTER SEQUENCE esm.mkr_joins_id_seq OWNED BY esm.mkr_joins.id;


--
-- Name: mkr_joins; Type: TABLE; Schema: esmv2; Owner: user
--

CREATE TABLE esmv2.mkr_joins (
    id integer NOT NULL,
    from_address character varying(66) NOT NULL,
    immediate_caller character varying(66) NOT NULL,
    join_amount numeric(78,18) NOT NULL,
    contract_address character varying(66) NOT NULL,
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE esmv2.mkr_joins OWNER TO "user";

--
-- Name: mkr_joins_id_seq; Type: SEQUENCE; Schema: esmv2; Owner: user
--

CREATE SEQUENCE esmv2.mkr_joins_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE esmv2.mkr_joins_id_seq OWNER TO "user";

--
-- Name: mkr_joins_id_seq; Type: SEQUENCE OWNED BY; Schema: esmv2; Owner: user
--

ALTER SEQUENCE esmv2.mkr_joins_id_seq OWNED BY esmv2.mkr_joins.id;


--
-- Name: logs; Type: TABLE; Schema: extracted; Owner: user
--

CREATE TABLE extracted.logs (
    id integer NOT NULL,
    block_id integer NOT NULL,
    log_index integer NOT NULL,
    address character varying(66) NOT NULL,
    data text NOT NULL,
    topics character varying(400) NOT NULL,
    tx_id integer NOT NULL
);


ALTER TABLE extracted.logs OWNER TO "user";

--
-- Name: logs_id_seq; Type: SEQUENCE; Schema: extracted; Owner: user
--

CREATE SEQUENCE extracted.logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE extracted.logs_id_seq OWNER TO "user";

--
-- Name: logs_id_seq; Type: SEQUENCE OWNED BY; Schema: extracted; Owner: user
--

ALTER SEQUENCE extracted.logs_id_seq OWNED BY extracted.logs.id;


--
-- Name: logs; Type: TABLE; Schema: extractedarbitrum; Owner: user
--

CREATE TABLE extractedarbitrum.logs (
    id integer NOT NULL,
    block_id integer NOT NULL,
    log_index integer NOT NULL,
    address character varying(66) NOT NULL,
    data text NOT NULL,
    topics character varying(400) NOT NULL,
    tx_id integer NOT NULL
);


ALTER TABLE extractedarbitrum.logs OWNER TO "user";

--
-- Name: logs_id_seq; Type: SEQUENCE; Schema: extractedarbitrum; Owner: user
--

CREATE SEQUENCE extractedarbitrum.logs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE extractedarbitrum.logs_id_seq OWNER TO "user";

--
-- Name: logs_id_seq; Type: SEQUENCE OWNED BY; Schema: extractedarbitrum; Owner: user
--

ALTER SEQUENCE extractedarbitrum.logs_id_seq OWNED BY extractedarbitrum.logs.id;


--
-- Name: balances; Type: TABLE; Schema: mkr; Owner: user
--

CREATE TABLE mkr.balances (
    id integer NOT NULL,
    address character(66) NOT NULL,
    amount numeric(78,18) NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE mkr.balances OWNER TO "user";

--
-- Name: balances_id_seq; Type: SEQUENCE; Schema: mkr; Owner: user
--

CREATE SEQUENCE mkr.balances_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE mkr.balances_id_seq OWNER TO "user";

--
-- Name: balances_id_seq; Type: SEQUENCE OWNED BY; Schema: mkr; Owner: user
--

ALTER SEQUENCE mkr.balances_id_seq OWNED BY mkr.balances.id;


--
-- Name: transfer_event; Type: TABLE; Schema: mkr; Owner: user
--

CREATE TABLE mkr.transfer_event (
    id integer NOT NULL,
    sender character varying(66) NOT NULL,
    receiver character varying(66) NOT NULL,
    amount numeric(78,18) NOT NULL,
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE mkr.transfer_event OWNER TO "user";

--
-- Name: transfer_event_id_seq; Type: SEQUENCE; Schema: mkr; Owner: user
--

CREATE SEQUENCE mkr.transfer_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE mkr.transfer_event_id_seq OWNER TO "user";

--
-- Name: transfer_event_id_seq; Type: SEQUENCE OWNED BY; Schema: mkr; Owner: user
--

ALTER SEQUENCE mkr.transfer_event_id_seq OWNED BY mkr.transfer_event.id;


--
-- Name: poll_created_event; Type: TABLE; Schema: polling; Owner: user
--

CREATE TABLE polling.poll_created_event (
    id integer NOT NULL,
    creator character varying(66) NOT NULL,
    poll_id integer NOT NULL,
    block_created integer NOT NULL,
    start_date integer NOT NULL,
    end_date integer NOT NULL,
    multi_hash character varying NOT NULL,
    url character varying NOT NULL,
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE polling.poll_created_event OWNER TO "user";

--
-- Name: poll_created_event_id_seq; Type: SEQUENCE; Schema: polling; Owner: user
--

CREATE SEQUENCE polling.poll_created_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE polling.poll_created_event_id_seq OWNER TO "user";

--
-- Name: poll_created_event_id_seq; Type: SEQUENCE OWNED BY; Schema: polling; Owner: user
--

ALTER SEQUENCE polling.poll_created_event_id_seq OWNED BY polling.poll_created_event.id;


--
-- Name: poll_withdrawn_event; Type: TABLE; Schema: polling; Owner: user
--

CREATE TABLE polling.poll_withdrawn_event (
    id integer NOT NULL,
    creator character varying(66) NOT NULL,
    poll_id integer NOT NULL,
    block_withdrawn integer NOT NULL,
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL
);


ALTER TABLE polling.poll_withdrawn_event OWNER TO "user";

--
-- Name: poll_withdrawn_event_id_seq; Type: SEQUENCE; Schema: polling; Owner: user
--

CREATE SEQUENCE polling.poll_withdrawn_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE polling.poll_withdrawn_event_id_seq OWNER TO "user";

--
-- Name: poll_withdrawn_event_id_seq; Type: SEQUENCE OWNED BY; Schema: polling; Owner: user
--

ALTER SEQUENCE polling.poll_withdrawn_event_id_seq OWNED BY polling.poll_withdrawn_event.id;


--
-- Name: voted_event; Type: TABLE; Schema: polling; Owner: user
--

CREATE TABLE polling.voted_event (
    id integer NOT NULL,
    voter character varying(66) NOT NULL,
    poll_id integer NOT NULL,
    option_id integer,
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL,
    option_id_raw character varying(66),
    chain_id integer
);


ALTER TABLE polling.voted_event OWNER TO "user";

--
-- Name: voted_event_arbitrum; Type: TABLE; Schema: polling; Owner: user
--

CREATE TABLE polling.voted_event_arbitrum (
    id integer NOT NULL,
    voter character varying(66) NOT NULL,
    poll_id integer NOT NULL,
    option_id integer,
    option_id_raw character varying(66),
    log_index integer NOT NULL,
    tx_id integer NOT NULL,
    block_id integer NOT NULL,
    chain_id integer NOT NULL
);


ALTER TABLE polling.voted_event_arbitrum OWNER TO "user";

--
-- Name: voted_event_arbitrum_id_seq; Type: SEQUENCE; Schema: polling; Owner: user
--

CREATE SEQUENCE polling.voted_event_arbitrum_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE polling.voted_event_arbitrum_id_seq OWNER TO "user";

--
-- Name: voted_event_arbitrum_id_seq; Type: SEQUENCE OWNED BY; Schema: polling; Owner: user
--

ALTER SEQUENCE polling.voted_event_arbitrum_id_seq OWNED BY polling.voted_event_arbitrum.id;


--
-- Name: voted_event_id_seq; Type: SEQUENCE; Schema: polling; Owner: user
--

CREATE SEQUENCE polling.voted_event_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE polling.voted_event_id_seq OWNER TO "user";

--
-- Name: voted_event_id_seq; Type: SEQUENCE OWNED BY; Schema: polling; Owner: user
--

ALTER SEQUENCE polling.voted_event_id_seq OWNED BY polling.voted_event.id;


--
-- Name: migrations_mkr; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.migrations_mkr (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.migrations_mkr OWNER TO "user";

--
-- Name: migrations_vulcan2x_core; Type: TABLE; Schema: public; Owner: user
--

CREATE TABLE public.migrations_vulcan2x_core (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    hash character varying(40) NOT NULL,
    executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.migrations_vulcan2x_core OWNER TO "user";

--
-- Name: address; Type: TABLE; Schema: vulcan2x; Owner: user
--

CREATE TABLE vulcan2x.address (
    address character varying(66) NOT NULL,
    bytecode_hash character varying(66),
    is_contract boolean DEFAULT false NOT NULL
);


ALTER TABLE vulcan2x.address OWNER TO "user";

--
-- Name: block; Type: TABLE; Schema: vulcan2x; Owner: user
--

CREATE TABLE vulcan2x.block (
    id integer NOT NULL,
    number integer NOT NULL,
    hash character varying(66) NOT NULL,
    "timestamp" timestamp with time zone NOT NULL
);


ALTER TABLE vulcan2x.block OWNER TO "user";

--
-- Name: block_id_seq; Type: SEQUENCE; Schema: vulcan2x; Owner: user
--

CREATE SEQUENCE vulcan2x.block_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE vulcan2x.block_id_seq OWNER TO "user";

--
-- Name: block_id_seq; Type: SEQUENCE OWNED BY; Schema: vulcan2x; Owner: user
--

ALTER SEQUENCE vulcan2x.block_id_seq OWNED BY vulcan2x.block.id;


--
-- Name: enhanced_transaction; Type: TABLE; Schema: vulcan2x; Owner: user
--

CREATE TABLE vulcan2x.enhanced_transaction (
    hash character varying(66) NOT NULL,
    method_name character varying(255),
    arg0 text,
    arg1 text,
    arg2 text,
    args json
);


ALTER TABLE vulcan2x.enhanced_transaction OWNER TO "user";

--
-- Name: job; Type: TABLE; Schema: vulcan2x; Owner: user
--

CREATE TABLE vulcan2x.job (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    last_block_id integer NOT NULL,
    status public.job_status DEFAULT 'not-ready'::public.job_status NOT NULL,
    extra_info text
);


ALTER TABLE vulcan2x.job OWNER TO "user";

--
-- Name: job_id_seq; Type: SEQUENCE; Schema: vulcan2x; Owner: user
--

CREATE SEQUENCE vulcan2x.job_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE vulcan2x.job_id_seq OWNER TO "user";

--
-- Name: job_id_seq; Type: SEQUENCE OWNED BY; Schema: vulcan2x; Owner: user
--

ALTER SEQUENCE vulcan2x.job_id_seq OWNED BY vulcan2x.job.id;


--
-- Name: transaction; Type: TABLE; Schema: vulcan2x; Owner: user
--

CREATE TABLE vulcan2x.transaction (
    id integer NOT NULL,
    hash character varying(66) NOT NULL,
    to_address character varying(66) NOT NULL,
    from_address character varying(66) NOT NULL,
    block_id integer NOT NULL,
    nonce integer,
    value numeric(78,0),
    gas_limit numeric(78,0),
    gas_price numeric(78,0),
    data text
);


ALTER TABLE vulcan2x.transaction OWNER TO "user";

--
-- Name: transaction_id_seq; Type: SEQUENCE; Schema: vulcan2x; Owner: user
--

CREATE SEQUENCE vulcan2x.transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE vulcan2x.transaction_id_seq OWNER TO "user";

--
-- Name: transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: vulcan2x; Owner: user
--

ALTER SEQUENCE vulcan2x.transaction_id_seq OWNED BY vulcan2x.transaction.id;


--
-- Name: address; Type: TABLE; Schema: vulcan2xarbitrum; Owner: user
--

CREATE TABLE vulcan2xarbitrum.address (
    address character varying(66) NOT NULL,
    bytecode_hash character varying(66),
    is_contract boolean DEFAULT false NOT NULL
);


ALTER TABLE vulcan2xarbitrum.address OWNER TO "user";

--
-- Name: block; Type: TABLE; Schema: vulcan2xarbitrum; Owner: user
--

CREATE TABLE vulcan2xarbitrum.block (
    id integer NOT NULL,
    number integer NOT NULL,
    hash character varying(66) NOT NULL,
    "timestamp" timestamp with time zone NOT NULL
);


ALTER TABLE vulcan2xarbitrum.block OWNER TO "user";

--
-- Name: block_id_seq; Type: SEQUENCE; Schema: vulcan2xarbitrum; Owner: user
--

CREATE SEQUENCE vulcan2xarbitrum.block_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE vulcan2xarbitrum.block_id_seq OWNER TO "user";

--
-- Name: block_id_seq; Type: SEQUENCE OWNED BY; Schema: vulcan2xarbitrum; Owner: user
--

ALTER SEQUENCE vulcan2xarbitrum.block_id_seq OWNED BY vulcan2xarbitrum.block.id;


--
-- Name: enhanced_transaction; Type: TABLE; Schema: vulcan2xarbitrum; Owner: user
--

CREATE TABLE vulcan2xarbitrum.enhanced_transaction (
    hash character varying(66) NOT NULL,
    method_name character varying(255),
    arg0 text,
    arg1 text,
    arg2 text,
    args json
);


ALTER TABLE vulcan2xarbitrum.enhanced_transaction OWNER TO "user";

--
-- Name: job; Type: TABLE; Schema: vulcan2xarbitrum; Owner: user
--

CREATE TABLE vulcan2xarbitrum.job (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    last_block_id integer NOT NULL,
    status public.job_status DEFAULT 'not-ready'::public.job_status NOT NULL,
    extra_info text
);


ALTER TABLE vulcan2xarbitrum.job OWNER TO "user";

--
-- Name: job_id_seq; Type: SEQUENCE; Schema: vulcan2xarbitrum; Owner: user
--

CREATE SEQUENCE vulcan2xarbitrum.job_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE vulcan2xarbitrum.job_id_seq OWNER TO "user";

--
-- Name: job_id_seq; Type: SEQUENCE OWNED BY; Schema: vulcan2xarbitrum; Owner: user
--

ALTER SEQUENCE vulcan2xarbitrum.job_id_seq OWNED BY vulcan2xarbitrum.job.id;


--
-- Name: transaction; Type: TABLE; Schema: vulcan2xarbitrum; Owner: user
--

CREATE TABLE vulcan2xarbitrum.transaction (
    id integer NOT NULL,
    hash character varying(66) NOT NULL,
    to_address character varying(66) NOT NULL,
    from_address character varying(66) NOT NULL,
    block_id integer NOT NULL,
    nonce integer,
    value numeric(78,0),
    gas_limit numeric(78,0),
    gas_price numeric(78,0),
    data text
);


ALTER TABLE vulcan2xarbitrum.transaction OWNER TO "user";

--
-- Name: transaction_id_seq; Type: SEQUENCE; Schema: vulcan2xarbitrum; Owner: user
--

CREATE SEQUENCE vulcan2xarbitrum.transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE vulcan2xarbitrum.transaction_id_seq OWNER TO "user";

--
-- Name: transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: vulcan2xarbitrum; Owner: user
--

ALTER SEQUENCE vulcan2xarbitrum.transaction_id_seq OWNED BY vulcan2xarbitrum.transaction.id;


--
-- Name: chain id; Type: DEFAULT; Schema: chains; Owner: user
--

ALTER TABLE ONLY chains.chain ALTER COLUMN id SET DEFAULT nextval('chains.chain_id_seq'::regclass);


--
-- Name: balances id; Type: DEFAULT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.balances ALTER COLUMN id SET DEFAULT nextval('dschief.balances_id_seq'::regclass);


--
-- Name: delegate_lock id; Type: DEFAULT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.delegate_lock ALTER COLUMN id SET DEFAULT nextval('dschief.delegate_lock_id_seq'::regclass);


--
-- Name: lock id; Type: DEFAULT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.lock ALTER COLUMN id SET DEFAULT nextval('dschief.lock_id_seq'::regclass);


--
-- Name: vote_delegate_created_event id; Type: DEFAULT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.vote_delegate_created_event ALTER COLUMN id SET DEFAULT nextval('dschief.vote_delegate_created_event_id_seq'::regclass);


--
-- Name: vote_proxy_created_event id; Type: DEFAULT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.vote_proxy_created_event ALTER COLUMN id SET DEFAULT nextval('dschief.vote_proxy_created_event_id_seq'::regclass);


--
-- Name: mkr_joins id; Type: DEFAULT; Schema: esm; Owner: user
--

ALTER TABLE ONLY esm.mkr_joins ALTER COLUMN id SET DEFAULT nextval('esm.mkr_joins_id_seq'::regclass);


--
-- Name: mkr_joins id; Type: DEFAULT; Schema: esmv2; Owner: user
--

ALTER TABLE ONLY esmv2.mkr_joins ALTER COLUMN id SET DEFAULT nextval('esmv2.mkr_joins_id_seq'::regclass);


--
-- Name: logs id; Type: DEFAULT; Schema: extracted; Owner: user
--

ALTER TABLE ONLY extracted.logs ALTER COLUMN id SET DEFAULT nextval('extracted.logs_id_seq'::regclass);


--
-- Name: logs id; Type: DEFAULT; Schema: extractedarbitrum; Owner: user
--

ALTER TABLE ONLY extractedarbitrum.logs ALTER COLUMN id SET DEFAULT nextval('extractedarbitrum.logs_id_seq'::regclass);


--
-- Name: balances id; Type: DEFAULT; Schema: mkr; Owner: user
--

ALTER TABLE ONLY mkr.balances ALTER COLUMN id SET DEFAULT nextval('mkr.balances_id_seq'::regclass);


--
-- Name: transfer_event id; Type: DEFAULT; Schema: mkr; Owner: user
--

ALTER TABLE ONLY mkr.transfer_event ALTER COLUMN id SET DEFAULT nextval('mkr.transfer_event_id_seq'::regclass);


--
-- Name: poll_created_event id; Type: DEFAULT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.poll_created_event ALTER COLUMN id SET DEFAULT nextval('polling.poll_created_event_id_seq'::regclass);


--
-- Name: poll_withdrawn_event id; Type: DEFAULT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.poll_withdrawn_event ALTER COLUMN id SET DEFAULT nextval('polling.poll_withdrawn_event_id_seq'::regclass);


--
-- Name: voted_event id; Type: DEFAULT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.voted_event ALTER COLUMN id SET DEFAULT nextval('polling.voted_event_id_seq'::regclass);


--
-- Name: voted_event_arbitrum id; Type: DEFAULT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.voted_event_arbitrum ALTER COLUMN id SET DEFAULT nextval('polling.voted_event_arbitrum_id_seq'::regclass);


--
-- Name: block id; Type: DEFAULT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.block ALTER COLUMN id SET DEFAULT nextval('vulcan2x.block_id_seq'::regclass);


--
-- Name: job id; Type: DEFAULT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.job ALTER COLUMN id SET DEFAULT nextval('vulcan2x.job_id_seq'::regclass);


--
-- Name: transaction id; Type: DEFAULT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.transaction ALTER COLUMN id SET DEFAULT nextval('vulcan2x.transaction_id_seq'::regclass);


--
-- Name: block id; Type: DEFAULT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.block ALTER COLUMN id SET DEFAULT nextval('vulcan2xarbitrum.block_id_seq'::regclass);


--
-- Name: job id; Type: DEFAULT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.job ALTER COLUMN id SET DEFAULT nextval('vulcan2xarbitrum.job_id_seq'::regclass);


--
-- Name: transaction id; Type: DEFAULT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.transaction ALTER COLUMN id SET DEFAULT nextval('vulcan2xarbitrum.transaction_id_seq'::regclass);


--
-- Data for Name: chain; Type: TABLE DATA; Schema: chains; Owner: user
--

COPY chains.chain (id, chain_id, name) FROM stdin;
1	421613	arbitrumTestnet
2	5	goerli
\.


--
-- Data for Name: balances; Type: TABLE DATA; Schema: dschief; Owner: user
--

COPY dschief.balances (id, address, amount, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: delegate_lock; Type: TABLE DATA; Schema: dschief; Owner: user
--

COPY dschief.delegate_lock (id, from_address, immediate_caller, lock, contract_address, log_index, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: lock; Type: TABLE DATA; Schema: dschief; Owner: user
--

COPY dschief.lock (id, from_address, immediate_caller, lock, contract_address, log_index, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: vote_delegate_created_event; Type: TABLE DATA; Schema: dschief; Owner: user
--

COPY dschief.vote_delegate_created_event (id, delegate, vote_delegate, log_index, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: vote_proxy_created_event; Type: TABLE DATA; Schema: dschief; Owner: user
--

COPY dschief.vote_proxy_created_event (id, cold, hot, vote_proxy, log_index, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: mkr_joins; Type: TABLE DATA; Schema: esm; Owner: user
--

COPY esm.mkr_joins (id, from_address, immediate_caller, join_amount, contract_address, log_index, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: mkr_joins; Type: TABLE DATA; Schema: esmv2; Owner: user
--

COPY esmv2.mkr_joins (id, from_address, immediate_caller, join_amount, contract_address, log_index, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: logs; Type: TABLE DATA; Schema: extracted; Owner: user
--

COPY extracted.logs (id, block_id, log_index, address, data, topics, tx_id) FROM stdin;
1	62	1	0xc5e4eab513a7cd12b2335e8a0d57273e13d499f7	0x	{0xce241d7ca1f669fee44b6fc00b8eba2df3bb514eed0f6f668f8f89096e81ed94,0x000000000000000000000000db33dfd3d61308c33c63209845dad3e6bfb2c674}	3
2	89	2	0xc5e4eab513a7cd12b2335e8a0d57273e13d499f7	0x00000000000000000000000000000000000000000000d3c21bcecceda1000000	{0x0f6798a560793a54c3bcfe86a93cde1e73087d944c0ea20544137d4121396885,0x000000000000000000000000db33dfd3d61308c33c63209845dad3e6bfb2c674}	1
3	91	0	0xc5e4eab513a7cd12b2335e8a0d57273e13d499f7	0x	{0x1abebea81bfa2637f28358c371278fb15ede7ea8dd28d2e03b112ff6d936ada4,0x000000000000000000000000b9b861e8f9b29322815260b6883bbe1dbc91da8a}	2
\.


--
-- Data for Name: logs; Type: TABLE DATA; Schema: extractedarbitrum; Owner: user
--

COPY extractedarbitrum.logs (id, block_id, log_index, address, data, topics, tx_id) FROM stdin;
\.


--
-- Data for Name: balances; Type: TABLE DATA; Schema: mkr; Owner: user
--

COPY mkr.balances (id, address, amount, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: transfer_event; Type: TABLE DATA; Schema: mkr; Owner: user
--

COPY mkr.transfer_event (id, sender, receiver, amount, log_index, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: poll_created_event; Type: TABLE DATA; Schema: polling; Owner: user
--

COPY polling.poll_created_event (id, creator, poll_id, block_created, start_date, end_date, multi_hash, url, log_index, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: poll_withdrawn_event; Type: TABLE DATA; Schema: polling; Owner: user
--

COPY polling.poll_withdrawn_event (id, creator, poll_id, block_withdrawn, log_index, tx_id, block_id) FROM stdin;
\.


--
-- Data for Name: voted_event; Type: TABLE DATA; Schema: polling; Owner: user
--

COPY polling.voted_event (id, voter, poll_id, option_id, log_index, tx_id, block_id, option_id_raw, chain_id) FROM stdin;
\.


--
-- Data for Name: voted_event_arbitrum; Type: TABLE DATA; Schema: polling; Owner: user
--

COPY polling.voted_event_arbitrum (id, voter, poll_id, option_id, option_id_raw, log_index, tx_id, block_id, chain_id) FROM stdin;
\.


--
-- Data for Name: migrations_mkr; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.migrations_mkr (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	07df1e838505a575c55d08e52e3b0d77955b5ad9	2023-05-02 01:50:45.660588
1	mkr-token-init	6bd4f885f95d28877debf029b81e1cc4a31de183	2023-05-02 01:50:45.668239
2	polling-init	55fa788d4f1e207fb8035f91b6b0d46e6811987d	2023-05-02 01:50:45.678529
3	polling-views	bf85462959f7a4fb98527547df9c7d2c7b2eefbd	2023-05-02 01:50:45.69536
4	dschief-init	e0ce34cbf37ac68a8e8c28a36c3fb5547834aef1	2023-05-02 01:50:45.701233
5	dschief-vote-proxies	2b2c103ab00b04b08abdde861b8613408c84e7b5	2023-05-02 01:50:45.709577
6	votes-with-dschiefs	3eaf466c8fef3d07da7416713e69a072426f2411	2023-05-02 01:50:45.71743
7	polling-unique-votes	f94587fdce58a186367a7754c8a373fb8ce359b9	2023-05-02 01:50:45.724226
8	optimize	32b1875a7b57c6322d358857a2279232ae0ee103	2023-05-02 01:50:45.72862
9	fix-polling-unique	cf3f30285ef810ceeb9849873fdbd3a544abe55f	2023-05-02 01:50:45.731822
10	fix-current-vote	51becc91cbdb8080bedf7068666109921cfcc77c	2023-05-02 01:50:45.735046
11	fix-total-mkr-weight	6499299b7f05586e8b4c76d157a8400d4d41d527	2023-05-02 01:50:45.739042
12	revert-optimize	653fdb7d29eeacea54628b9544b3fcf73cf0e6c5	2023-05-02 01:50:45.74361
13	revert-revert	17b9d21a1cf70aa05455125bc57a5611c0602070	2023-05-02 01:50:45.746846
14	fix-optimized-mkr-balance	a431b3692d220b4dfeed59bdb2bab20728664bc4	2023-05-02 01:50:45.750095
15	valid-votes-block-number	8b19449941da0edf23aa9d0ea3df372e625c85d2	2023-05-02 01:50:45.753981
16	esm-init	251eb54044a938c7498d5052142be7413158b620	2023-05-02 01:50:45.758068
17	esm-query	ab13b81c2700ade1dcea8a4ea1a875a8a8d65aef	2023-05-02 01:50:45.764824
18	timestamp-not-block-number	eda4eb0b00ce78c12c4da3f9fe400d2ee2c670b0	2023-05-02 01:50:45.769024
19	current-block-queries	43f65d8b2178fcb3c3d4b2a3ac64f046aff3d34e	2023-05-02 01:50:45.774239
20	remove-timestamp-return	14c3a852e4fe128d9b1edfd4399dd525eff4b0df	2023-05-02 01:50:45.779502
21	vote-option-id-type	7310b882c1775819ec1c1585e4c5d83abf5f99d3	2023-05-02 01:50:45.783749
22	current-vote-ranked-choice	94e2720ee609c046f9d4fbddb68d72038cf3cbad	2023-05-02 01:50:45.78801
23	optimize-hot-or-cold	2910ba5418e847c19be33e4df7f174f2928995be	2023-05-02 01:50:45.791251
24	optimize-total-mkr-weight-proxy-and-no	2b0fe2600ff6e2b22b5642bba43a129e68d2fa88	2023-05-02 01:50:45.794381
25	all-current-votes	a833d09836c08ab2badbabb120b382668131e889	2023-05-02 01:50:45.797782
26	fix-all-active-vote-proxies	e12d01f9f768c6b3e6739c06ed27b5116f8c6e67	2023-05-02 01:50:45.800878
27	fix-hot-cold-flip-in-026	dbcd0e62f6b1185e6ac6509ceb8ddf97a5f61b19	2023-05-02 01:50:45.804584
28	unique-voters-fix-for-ranked-choice	e7fd2498e6e91fe2d3169ca2b99b1df465befd86	2023-05-02 01:50:45.808263
29	store-balances	3dd612be9c6bb81e9fdbb5c71522a400727ae697	2023-05-02 01:50:45.811498
30	store-chief-balances	b5d202e6fd8c52e62b5edad64e820b10640699f8	2023-05-02 01:50:45.817831
31	faster-polling-queries	be05803c693c93bd58cdcab33690e7d0149be916	2023-05-02 01:50:45.824506
32	faster-polling-apis	a6445115270efb32f01d7491f3593482768e51c6	2023-05-02 01:50:45.832714
33	polling-fixes	582b1b7d7ae00ca4ac3ea78444efde2a19d28828	2023-05-02 01:50:45.836735
34	dschief-vote-delegates	a2cdc87bf4be7472ac772cf2028d6f796f3ba6aa	2023-05-02 01:50:45.843578
35	all-vote-delegates	e45e96e7373fd5e061060aaf86c5756be8e4b103	2023-05-02 01:50:45.850545
36	double-linked-proxy	f027e655ea32026d8b592477ff0c753a70737565	2023-05-02 01:50:45.855133
37	all-current-votes-array	1ec02a261e5268d2f601000a819ec390a5c6fe16	2023-05-02 01:50:45.859632
38	all-current-votes-with-blocktimestamp	871d79c4eb35524e16994442804b18825be977fb	2023-05-02 01:50:45.863498
39	poll-votes-by-address	fe422475f35e865f9a6a7981fa2760a6aba38020	2023-05-02 01:50:45.86759
40	buggy-mkr-weight	6b4abc8cd5e5cf4b940377716ef57ed9b09c950b	2023-05-02 01:50:45.872023
41	hot-cold-chief-balances	8e6081d83f0db2b8e9d14beb1123dc7198a67cb3	2023-05-02 01:50:45.876508
42	handle-vote-proxy-created-after-poll-ends	44e3902a9291e2867334db700e2b1eee785512bb	2023-05-02 01:50:45.880171
43	buggy-poll-votes-by-address	25fd2d9a826a053f063836e1142d4ff556f34c23	2023-05-02 01:50:45.883896
44	rewrite-poll-votes-by-address	4f4fb2700d82a427101fd3e0e2bc2c0eda90c796	2023-05-02 01:50:45.88775
45	unique_voter_improvement	a831d34e097bd155e868947e5a6ba6af91349b8c	2023-05-02 01:50:45.891506
46	mkr-locked-delegate	042974da667fcf6b8b5fd3b9e85dee26737e20bc	2023-05-02 01:50:45.895282
47	mkr-delegated-to	808eeb0d6aa0ccfc5ea46025eb3f41f58f6e7ace	2023-05-02 01:50:45.898878
48	mkr-locked-delegate-with-hash	f592a35a68e84cc07bea73dbcef2ca53f7f71dd1	2023-05-02 01:50:45.903197
49	polling-by-id	bef43083b7fdd7e09f3097ec698871c3ba88a550	2023-05-02 01:50:45.907838
50	esm-v2-init	71efa4fbfe551c617d1a686950afee2e97725bdd	2023-05-02 01:50:45.91245
51	esm-v2-query	5728974c0e67e30014b369298c4dc3a55862136b	2023-05-02 01:50:45.920572
52	mkr-locked-delegate-array	57b9c28ed782cb910aa5bbfc3d41b2ef3d17cb77	2023-05-02 01:50:45.925358
53	all-locks-summed	6d622f56eebcc52260ef0070ff7666a780354cb8	2023-05-02 01:50:45.930102
54	mkr-locked-delegate-array-totals	b0fef906b3077439a008f26379a4f6b7a98efeb1	2023-05-02 01:50:45.934489
55	manual-lock-fix	ccbbd33546296bf0ea3712ff2346ffcb6d70d8b2	2023-05-02 01:50:45.940166
56	manual-lock-fix-2	17435c58ebaad7034c084961298826c0a9e90b43	2023-05-02 01:50:45.944649
57	manual-lock-fix-3	74eec08f834994af46f8ed0cd74a14ce565d734c	2023-05-02 01:50:45.949058
58	delegate_locks	11a39de8bd6aa5478c4c3ec475b52f45ea74cf19	2023-05-02 01:50:45.954358
59	new-delegate-event-queries	b3290ebf53446ba3656e24873d5f908948bc2e9b	2023-05-02 01:50:45.963704
60	arbitrum-polling-voted-event	33f8abf397b011350bf0889be4588c465cc92883	2023-05-02 01:50:45.969811
61	arbitrum-all-current-votes	eaa34cb02a401199af7492706152fc64a170cc2d	2023-05-02 01:50:45.977911
62	votes-at-time-arbitrum-ts-hash	a4e51703425cd3ec4f59339447063215c90ef67e	2023-05-02 01:50:45.984705
63	updated-arbitrum-all-current-votes	27a187f4625aa058da51ffda971f1b7f86045dc6	2023-05-02 01:50:45.990269
64	updated-polling-votes-at-time	29eab737d1f05a0fb298253f5ac25ff41a2071dc	2023-05-02 01:50:45.994315
65	live-poll-count	df0d08f3545f9833dc63672cb064402f0a8867a0	2023-05-02 01:50:45.998181
66	all-delegates-sorted	6dbcdeadb811a80a507dda0283e1983e31dec67f	2023-05-02 01:50:46.003716
67	updated-live-poll-count	2048474874524b54b0123d366718ecf225f10624	2023-05-02 01:50:46.008856
68	delegation-metrics	8f6a7424245a427558e52313af00dd3f957c50ed	2023-05-02 01:50:46.013668
69	all-delegates-paginated-with-random	29d1940df53fdf28ce3e0ae3495edffa58704db9	2023-05-02 01:50:46.018093
70	total-mkr-delegated-to-group	08bba1d42f4d3f48f3917887b7e6412fcd519871	2023-05-02 01:50:46.024021
71	delegates-sorted-by-type	1614a345fef39a548ea00549b641ce8ed52a945a	2023-05-02 01:50:46.028293
\.


--
-- Data for Name: migrations_vulcan2x_core; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.migrations_vulcan2x_core (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	37f1979105c4bfba94329a8507ec41fddb9f29c1	2023-05-02 01:50:45.440163
1	vulcan2x	bded5b7bd4b47fde5effa59b95d12e4575212a6f	2023-05-02 01:50:45.464201
2	extract	f3b2668b094fc39f2323258442796adbd8ef9858	2023-05-02 01:50:45.487712
3	vulcan2x-indexes	5ee2f922590b7ac796f9ad1b69985c246dd52e48	2023-05-02 01:50:45.499969
4	vulcan2x-indexes-2	16c4f03e8a30ef7c5a8249a68fa8c6fe48a48a0c	2023-05-02 01:50:45.507841
5	vulcan2x-indexes-3	4dbb6a537ee7dfe229365ae8d5b04847deb9a1ae	2023-05-02 01:50:45.515164
6	vulcan2x-tx-new-columns	38cea6cc3f2ea509d3961cfa899bdc84f2b4056f	2023-05-02 01:50:45.521632
7	vulcan2x-address	04e43db73f9f553279a28377ef90893fc665b076	2023-05-02 01:50:45.52671
8	vulcan2x-enhanced-tx	2abaf0774aa31fffdb0e24a27b77203cd62d6d9e	2023-05-02 01:50:45.531885
9	api-init	ab00c5bcba931cfa02377e0747e2f8644f778a19	2023-05-02 01:50:45.539361
10	archiver-init	5c19daa71e146875c3435007894c49dc2d19121b	2023-05-02 01:50:45.543284
11	redo-jobs	f8408190950d4fb105b8995d220ae7ef034c8875	2023-05-02 01:50:45.551234
12	job-status	2f7ff24a3dfb809145f721fb27ece628b8058eb3	2023-05-02 01:50:45.560134
13	clear-control-tables	e0f1fd3e0afefc12ecaa0739aaedc95768316d3e	2023-05-02 01:50:45.572328
14	vulcan2xArbitrum	69f5299c5ae669083f12fcb45e40fe5a6d1c3c4b	2023-05-02 01:50:45.578651
\.


--
-- Data for Name: address; Type: TABLE DATA; Schema: vulcan2x; Owner: user
--

COPY vulcan2x.address (address, bytecode_hash, is_contract) FROM stdin;
\.


--
-- Data for Name: block; Type: TABLE DATA; Schema: vulcan2x; Owner: user
--

COPY vulcan2x.block (id, number, hash, "timestamp") FROM stdin;
1	5273000	0xaee75828538cf30236e4d18260ce2188e1de0416103b6f2b151a9a80aa704a0c	2021-08-06 16:08:08+00
2	5273001	0x90adce64af84dfca73c0850e0166f66f41c51c579f70e20cf64b2a6d0c38e0c8	2021-08-06 16:08:23+00
3	5273002	0x4bfe8ed2fea52e3a5270144e411f37692a68efff6a04eeb6ae9ebc0afd4d586d	2021-08-06 16:08:38+00
4	5273003	0xdeb2dff45add29f6f714a11ef2841f88c640cb66ad5bfc480da1164a4fe0a409	2021-08-06 16:08:53+00
5	5273004	0x2297114e415c60da74c10b4b368ceedc45aeb245aa8be9a4cdb7f57079b0083b	2021-08-06 16:09:08+00
6	5273005	0xaa02936dcdfdf3671fb033c62979f271e4010c8f389e8b00f53412f14d3be179	2021-08-06 16:09:23+00
7	5273006	0xa1be74897c29ad10091b12954e7c7f7a52550a3419be039545c9a8f5f413f39f	2021-08-06 16:09:38+00
8	5273007	0x33d47d0a287f3f27bfacbd2481ecad62eafd7c0feb74742a2f1e37cf2cdcc2f7	2021-08-06 16:09:53+00
9	5273008	0xa5943b2db37fec68b63704386fd912f840973a040bb36663f77ad55783caf02c	2021-08-06 16:10:08+00
10	5273009	0xa4911f76dc2aaaf8c1e9d033f0afb6bf8b524968ac32d02d586e3e7fc31405a5	2021-08-06 16:10:23+00
11	5273010	0x81e6ea04325cb77a34c173026c8246eab1f230b2ea9403e77dd6ac78999d490f	2021-08-06 16:10:38+00
12	5273011	0x4957f304ca0a2a8dcf84b427625f20184271e1649f76bb1cc89c0b135600d3d1	2021-08-06 16:10:53+00
13	5273012	0xf1aafa300a8dafb359cea07e4ff4a581840724af2a2ee43b207cccdfe81a4c3b	2021-08-06 16:11:08+00
14	5273013	0xda6b48697c5ef6ae6b3feab759b0aef1b49dc6c748fd09421371de3d4729da4c	2021-08-06 16:11:23+00
15	5273014	0x05efa76228eb67e4d70be6492155c18071241ba797ca2b60908ede375174227d	2021-08-06 16:11:38+00
16	5273015	0x078a23411b45bfe171fb93e8f970ac39280c9d74df9b50becfeb2d364b7005b1	2021-08-06 16:11:53+00
17	5273016	0xebbd59e56b7be72ec8bb8d7f52390a311ae072c2aa56e37900b95eb612b4ac28	2021-08-06 16:12:08+00
18	5273017	0xa3d88221306aa08f434b2e5cc8e60393d58ee850599386e9771e6e73a597c73f	2021-08-06 16:12:23+00
19	5273018	0x8026cb2e919ce2c4224ccf1fa5ed88fbf63c007aac37e2ab89cf7b7963df23d4	2021-08-06 16:12:38+00
20	5273019	0x96fa2e239e0b03425d6f4bcc52befc7e11906ed66f723ae61b663a67a764b5e0	2021-08-06 16:12:53+00
21	5273020	0x05d0149f98cde20e86aeac926ba7a5b5b7046265366da639787b246154d8ce64	2021-08-06 16:13:08+00
22	5273021	0x651f0e11985f55340244e572b9aaa87530f0fa88d44fbac577f00c9523733f72	2021-08-06 16:13:23+00
23	5273022	0xfae350f70060cde86a6325d4cebfe57fdae65aaa6a98ff552cf61f2aedd4af13	2021-08-06 16:13:38+00
24	5273023	0x59b1b46553b79c6c0c0dadc7c90e4a08676951bcfdedbd4b289602722961c24f	2021-08-06 16:13:53+00
25	5273024	0x7dcf93d1e1846872df170d86c52965be66ec6d11abdab46d655bc2c8168ccebb	2021-08-06 16:14:08+00
26	5273025	0x4e42e3970c887634b52a2750eedb4c94d10aac35951682666df231c7c4b964ea	2021-08-06 16:14:23+00
27	5273026	0x9598ccf6bdc19c6454f2e6790ed7cd903edef0141402ed8677d33f6d0a4359eb	2021-08-06 16:14:38+00
28	5273027	0xf0698a33cf559a04d955b35301d4fad437c537b13fc055f37cd8b927c3fa4c12	2021-08-06 16:14:53+00
29	5273028	0x82f2261cc37a9a1034d3dda48bb69048858e29159ae7745d6a9af8bea824e806	2021-08-06 16:15:08+00
30	5273029	0x8f8b18348a6ed2acf8e5f78009b9bc43ec42d955efdc28ef7f85aa6d33be7170	2021-08-06 16:15:23+00
31	5273030	0xc44554ce682c36d4c0bb25dfcca272579dfbb3c5ecc155a6534b11b785928cd4	2021-08-06 16:15:38+00
32	5273031	0x74584d4b8897ecdc7acc860493b717000b4082a47e80f7a693872e2d12d58469	2021-08-06 16:15:53+00
33	5273032	0x7c64471a883f5e56a40fe08857e7616745f82b0c3d0f172dbd4b8374e5c7d740	2021-08-06 16:16:08+00
34	5273033	0x9581a3d3d23318ba424903d2b1e2c1f23b06ba477ef5ec25714cf9cdadbc755f	2021-08-06 16:16:23+00
35	5273034	0x2e6eeabfd350fc550eb4a72efd4c4164d92370de32b5ab375cce12596d38da58	2021-08-06 16:16:38+00
36	5273035	0x570fdd5088e9f4f2670139e7a39ca4e353dee1944a28e9734bb9e14383d228d9	2021-08-06 16:16:53+00
37	5273036	0xe85ff79fcb4edc6c9a1ded9cb7bee579a829b6a5688adf9cc04b94eb61d26cb1	2021-08-06 16:17:08+00
38	5273037	0x70b476d699f55e5d470935eac7611451262c7ae5787782ef7527774c502d880f	2021-08-06 16:17:23+00
39	5273038	0xa3a0e77591c6396fd8b9245128e596a63a5eb03d9b095ebbcfe14f59861e0256	2021-08-06 16:17:38+00
40	5273039	0x1f655815c794f7208486c532f68d07420717e50621dfa31883f3b2bd3686843b	2021-08-06 16:17:53+00
41	5273040	0xbd485ad3819bf5240af3b56ad39f36c3728a103cf486cbad2ab7b7d73035f9f2	2021-08-06 16:18:08+00
42	5273041	0xb1e6f9730bba8f405bc9fff698e0e5bb18cabcffe1a0261b7595bd6dfbeecb05	2021-08-06 16:18:23+00
43	5273042	0xdc3b6fdad049d5f106ba638a485a6291dfc0525e75474bb634f4312833b38863	2021-08-06 16:18:38+00
44	5273043	0x5aed3a64d5f6d5a4c18e192afd7ff3f763d97fdfb96b1b41a9e316da99f59d2e	2021-08-06 16:18:53+00
45	5273044	0xe86e356be31eb2ca5af89460a8a18fabd3f39353041a79216fbd70fe8c70e314	2021-08-06 16:19:08+00
46	5273045	0xdbaf97c953a4f4f757187c3a5d9e5d40f5fd13172999686a4cd97be673be3bff	2021-08-06 16:19:23+00
47	5273046	0x4fc66c61f57c520e331aace1437f086b8378cd62683117cc6db98519060eedc7	2021-08-06 16:19:38+00
48	5273047	0x41673c868bd00e84d20375a8a3fc6a3e0458b905c91aec7d609b8845622e408a	2021-08-06 16:19:53+00
49	5273048	0xf934962f0029c9478b4b338420a99eb1b42fb9fedd4658b290ad40f0b5a44fa6	2021-08-06 16:20:08+00
50	5273049	0x545598248d6c8832a0950fa82ffb0bcf9bc16474ab21c81fa26b15e8670fb3e7	2021-08-06 16:20:23+00
51	5273050	0x7c992a828ce29a4f0106e64e21017f260af42d66f585e5b404631cb339a94f20	2021-08-06 16:20:38+00
52	5273051	0xe81971e2110306fe0d659dbfe2a86c08cfb4b32e73c83547acecfabb10e6e4a7	2021-08-06 16:20:53+00
53	5273052	0x34c34b6032a5b23fa76e557781f31177b7cbf7243c1b343148502f5d486b3dad	2021-08-06 16:21:08+00
54	5273053	0x5dde30810efefebc4990ffcbc151a6f8a4c506426c81fe2f268ced03809d6164	2021-08-06 16:21:23+00
55	5273054	0x3308c13311bf6c6c7fe76d5c5b74b4103cf27fbe01a98fcbe4c4eb05aac2567d	2021-08-06 16:21:38+00
56	5273055	0xf63bebc89c5c9d6e63c32fb988530e8c2ff780b44328533ef6cd987439119095	2021-08-06 16:21:53+00
57	5273056	0xae9ee58f93d2c8491b9fc776301177c1c994fc0163ddf776145ba3d01fc86edf	2021-08-06 16:22:08+00
58	5273057	0xf52910fb862997aadc6241e020bc151f7df565c27c57ba24ff5a9d6e2778baca	2021-08-06 16:22:23+00
59	5273058	0x91bd5c2221e7627baf87631b98dc338286beb06920c39e2ca6738c91cdba0860	2021-08-06 16:22:38+00
60	5273059	0x4ba3c9119bc36c9372df42f8cbb72854be7d604dde71e1882fe38033a890bcff	2021-08-06 16:22:53+00
61	5273060	0xca3d836b0168143396dcee4605f4b6f3ce8f64989a66069b6e12b742df08fe31	2021-08-06 16:23:08+00
62	5273061	0xb9446954efee4c9f827a69f8fe11d9faa7cb199a532367845e95af7564932eb8	2021-08-06 16:23:23+00
63	5273062	0xbac16e891f3de723d17c8a5e70adbaa728bd51b9a2e45bb9fb3b3468e7071fcd	2021-08-06 16:23:38+00
64	5273063	0xbc044d7b7d0a4e54d81c0d4d5340286051a324c57d8924d80ea36c70f766e246	2021-08-06 16:23:53+00
65	5273064	0x882fc747f08162f519570b0b8571b35ff4a2320d508e0cef6929267c29927766	2021-08-06 16:24:08+00
66	5273065	0x1733cafa7828f814adbb1bc10b353530d1ed76e315bff9929dcf1042157711ca	2021-08-06 16:24:23+00
67	5273066	0x54f0cf9bfcf6e77a306580459fd5e6094d32961d97365a48b1618974653af876	2021-08-06 16:24:38+00
68	5273067	0x01c298805dc1ee28abd83a1a4bf72d4ad1dadc03582a0e2d453693d19b17b474	2021-08-06 16:24:53+00
69	5273068	0x7b87384b88b8d8d36d87516ce17d188d309a44f9e14e9adee54bf98c1b633db6	2021-08-06 16:25:08+00
70	5273069	0x91ecf00ba370d3ec440f59791b2c4001a08c9a5563a17e11e1065072710dcfb4	2021-08-06 16:25:23+00
71	5273070	0xa36325a4f5bba1ce427fc3fa1b38e9704c526051d0421a973f669b258714e7a8	2021-08-06 16:25:38+00
72	5273071	0x49fd3e22563f95f0d3728af723133638e2ff3c7d5c7920cd4607fe5741c64317	2021-08-06 16:25:53+00
73	5273072	0xe7009cf569ffe4533678cdb7a601938e3c02cf6e91661afba131b20ddbcbd365	2021-08-06 16:26:08+00
74	5273073	0x2d218b906068b18332b3a74446b297ca8914e0f1cc17877024652eff9fea0acb	2021-08-06 16:26:23+00
75	5273074	0x5539ed5ce05d820e6087940e7f0e7d8ed3bf7d88287efee9c306d2d86264e838	2021-08-06 16:26:38+00
76	5273075	0x2d92ef4f682e9071d174145bcbce33220eceb13154869b5c31a10d50dfc91744	2021-08-06 16:26:53+00
77	5273076	0x76817cd6ef9e0cffda76e802b4957df60b91826bebb59287512df2566efddd1d	2021-08-06 16:27:08+00
78	5273077	0xc84649060f250371884b16c5980734831bf12d4288a683f321e742f737db456e	2021-08-06 16:27:23+00
79	5273078	0xd6d44f3d16ba588dbfa396710a02c212c0098bafa97094457a696c2c5dfbfb90	2021-08-06 16:27:38+00
80	5273079	0x71eb3db361be479f2f5a914a8b83b2cac7397732c41b3f2405d6d6dac56bc1ea	2021-08-06 16:27:53+00
81	5273080	0x7e4b49e615d049aaf2e6d8459e0f06520353eb79b93d5d720f544d13f294cfad	2021-08-06 16:28:08+00
82	5273081	0x26db71c5d66dd01085d44ad2ca9f6cce269d9b93b4fa044c6e379b5b7c132a43	2021-08-06 16:28:23+00
83	5273082	0x2915013c5de88957b57f44392fb63a422f1548425fa2def828e631049bcdcb1a	2021-08-06 16:28:38+00
84	5273083	0x6beaf37722255c88b9e758bdd392a8732ba91688ac6ecb775d9e7e8b9b01fccc	2021-08-06 16:28:53+00
85	5273084	0xbe28b1e2388fc30b9e630008b0e09a25997616fd885f62fd8fcdc79341bf24e5	2021-08-06 16:29:08+00
86	5273085	0xad94a49273ab4ef52f82aff1debfa8bfd39899f99e1421fa8248b2de5e9e3d73	2021-08-06 16:29:23+00
87	5273086	0xab7ba3833b4af4a149fc028a6c915943a23979f3d806a98706ba46047fbacb6e	2021-08-06 16:29:38+00
88	5273087	0x042a7810eeb3dcb28055cbe3550731b0e2904acefe7dd417749bc400e99ef21e	2021-08-06 16:29:53+00
89	5273088	0x88f1eee493fcf2b2346aa67eca68027252e9f047fe74a4458e571de351f710d4	2021-08-06 16:30:08+00
90	5273089	0xa3526ffa76aeec8f81d4b15c32218f39c29dc5dd01186fa9b3f11bddc329eea3	2021-08-06 16:30:23+00
91	5273090	0xbde12dbca54eb3116e27deaf8823a582c14b3a43db97924ce45b0bc82d4d2a01	2021-08-06 16:30:38+00
92	5273091	0xf39ed210bd3320639864256f07b36af5d21c95a6fb46476eb1e169c804a0ae4b	2021-08-06 16:30:53+00
93	5273092	0xf73e4b189294548afed0a116d32c4f6b1ccab5bf10051ce9d7e060925ca04a91	2021-08-06 16:31:08+00
94	5273093	0x0bad26a363d7bd27fadbc278988630b5ebc869e09c465c093ebda18944ebd991	2021-08-06 16:31:23+00
95	5273094	0x2816bd802c4b323a81730f2f6b85fda4e80979c66d6b47b468b0d275a016c566	2021-08-06 16:31:38+00
96	5273095	0x6660917eb576b216af8320e93b3d07ff5b34ed47d355f24935a88f07e2afd53c	2021-08-06 16:31:53+00
97	5273096	0xb4738dbb6ace8e310a0386b959008ee05974dc9d1440760e64f3eb11fc4d642e	2021-08-06 16:32:08+00
98	5273097	0xbe8b84cda1408a6671ac64a08dc79473d46f2f0cc8512091d250f9afd7d8b335	2021-08-06 16:32:23+00
99	5273098	0x63795189dd4a9d3c4f40f9544c6cab637ebaeef6cc0352339590b266d1aaefac	2021-08-06 16:32:38+00
100	5273099	0x52090f396662ca2fc04fd374cb04fb59427eb464290037d040f46d6a76073d75	2021-08-06 16:32:53+00
101	5273100	0x05a6e16835405a93f37fd34062d5707b96d9922d878b9b65fcc8d4799b2fb176	2021-08-06 16:33:08+00
102	5273101	0x5b4435e9ff524cc6ccd1f0265de49d2434ec18d94c4583384d7bcd5f391f578f	2021-08-06 16:33:23+00
103	5273102	0x25d4df3462f99817edd46919f089916271addcefb0bb23e00db09e31cc7f2df7	2021-08-06 16:33:38+00
104	5273103	0x957365f58fe4ff39e21a8ed9e1b8fb887ddcc46ffbf589eaafcbc0110d7e0e76	2021-08-06 16:33:53+00
105	5273104	0x8a8103447db9159d40bc71be71e926b1e7652307dd902c8513d03b5541ffa682	2021-08-06 16:34:08+00
106	5273105	0xee860550044e220940bcf08c6a925ef8b7ace2fb6f042b070dc8188bce17c7f3	2021-08-06 16:34:23+00
107	5273106	0x9203e92595ce257ff2947d9949798978681ba1f6df8fdbceb9aaa8f2ae1d9719	2021-08-06 16:34:38+00
108	5273107	0xcea37e834acdf2983b5ec42071eab164612b4a063b77ad037a63c787a327f3ac	2021-08-06 16:34:53+00
109	5273108	0x2b858605f421286e34d741b9ef84a4464e5e1b3760182eb01810a5a86e9b8727	2021-08-06 16:35:08+00
110	5273109	0x9c2a5c4d3d035adff652718dd9376cdeb09e3aec95197faa77465a4ca8e95c5f	2021-08-06 16:35:23+00
111	5273110	0x86836f41d71110117e0c44aa52ba05f76b1e4b0474d3302b7d50a9fa48a75da7	2021-08-06 16:35:38+00
112	5273111	0x4ce13159ddbecc516d3e434d58e1fb50657f7c530affd0cfe8e73dfe9f48e4ee	2021-08-06 16:35:53+00
113	5273112	0x2bc2bc5838ccc697114496da0d3897dbbfeb4d951f0945f92b5f62e9b0139835	2021-08-06 16:36:08+00
114	5273113	0x7b64d602adfd335d36a2e961e0196f8aa9c30ca7f03c6bc629457951c67e05b9	2021-08-06 16:36:23+00
115	5273114	0x5680a3b6c083df824c39d2199cc0c12b597aae510c0efb406f7da5f9c1129758	2021-08-06 16:36:38+00
116	5273115	0x47c711b558c1f3d9e903013d6a7afaf431ba7c374cd3a42dc26cc26a6fab37c8	2021-08-06 16:36:53+00
117	5273116	0x7cdcde839f028b14408651bd7a4abd5ea29dc1eea7ba0948cbc682daafccb602	2021-08-06 16:37:08+00
118	5273117	0x713582a64844e39e2900a899a167d15092c0bc825924cc007cf2fcff1b826f07	2021-08-06 16:37:23+00
119	5273118	0x3dc91c89da4b1157163b6ea4623730b03644a9c773e2a37c68c32b0c98b5676e	2021-08-06 16:37:38+00
120	5273119	0xcd8496c5fa287aac814a840f3fd10092c10938e8a199d1b20b38b606b486b6d4	2021-08-06 16:37:53+00
121	5273120	0x6b7f61a4224895dbea6b44d4f0640ec083a21f02baec5aca0f3931be314e00bd	2021-08-06 16:38:08+00
122	5273121	0xe2a472fd8c0039866bfb39691f038b3d5d5ae66b5b4cf805b9cfc945b5947bba	2021-08-06 16:38:23+00
123	5273122	0x2e336a9c4fb4b8c1c5f015864839aa375dd86ae11a434e1582da0714cbe1eeaa	2021-08-06 16:38:38+00
124	5273123	0xe8db9a1813525cfcb4ff2cbdef6d2683cd9c00b154293c7e1af26184f58716bd	2021-08-06 16:38:53+00
125	5273124	0x4e3ceff298cc37bbd17b2e357a39bf16e5a81f8b612340b3b583ea5bc8098e79	2021-08-06 16:39:08+00
126	5273125	0xc0e1c625cbcdae58ea23b24b3a4ebe885272cd786e06aa81ef03c7c0c8c8f674	2021-08-06 16:39:23+00
127	5273126	0x2335b6b3973ac74be76e9fced85178fef3b62ad3562004a80bf006d15b677915	2021-08-06 16:39:38+00
128	5273127	0xf365cd1e8adf70b9e8170c287f956cb143ff836dd67cdd89b710520bdbc30ce2	2021-08-06 16:39:53+00
129	5273128	0xe18585b3b3a6bf31f664918c8ea6735fe3c14fae0aecaa51c521a28301460235	2021-08-06 16:40:08+00
130	5273129	0x4d7aedd8decb345c6eeeee9eb82b97cc5bd1c5f9a5764a16ce341efd65e23bec	2021-08-06 16:40:23+00
131	5273130	0x53ed695d86f3338acde5f29baa6a6ff02256bc80ba064d66e9155f55a95f32b1	2021-08-06 16:40:38+00
132	5273131	0x81349bd2a5ac72e46fd9c9d26275806630409c091bff3da3330219bcd7c195ea	2021-08-06 16:40:53+00
133	5273132	0x0968f152f10d2cba5002d1a11ea6edcee73be0649f9c0bc9a859f4910728d795	2021-08-06 16:41:08+00
134	5273133	0xa8d5accb6e77ce39394545acfcc54810764f9f86e18ced2da737a47585b59180	2021-08-06 16:41:23+00
135	5273134	0x0e449e9a68791d4a3558bf4227338a390a023a15ecaa7128cbce53519452af91	2021-08-06 16:41:38+00
136	5273135	0x354301588e0ec2189902d7a6b674579a2c8c3509868fe2e3a19f383778b628da	2021-08-06 16:41:53+00
137	5273136	0xd4924cc036be7fda3d5083571a1a976240e77723d6b8b80800a23f793047ff99	2021-08-06 16:42:08+00
138	5273137	0x1363f675c79ee39023105a26bee8fdf78015f5028e15c2e1681c386152b6e687	2021-08-06 16:42:23+00
139	5273138	0x5d0cb05e8ccd9b978714f51e21d5067e7434a8637d09269f079a1fbca7793bb1	2021-08-06 16:42:38+00
140	5273139	0x5e8a1cc31cc3dd3928c2801aa2b40c3ce972547f147989950576467482311cc0	2021-08-06 16:42:53+00
141	5273140	0xf6abf1dfb375303fee8dd1fdd5e42b4b99b0b70f2c92829d4cdffbb8fbaf1ade	2021-08-06 16:43:08+00
142	5273141	0x2f3e2c39c05cdd10b0e3d726b8189fecfe2cbefceba34f8b4de4bc5cc2ffda44	2021-08-06 16:43:23+00
143	5273142	0xa285b58b981d229a56598c0112cdf0e95410950bad051afa5758687062a94125	2021-08-06 16:43:38+00
144	5273143	0x82136181b75567c14197420dab51b2b070c848055b1af70621875e235cf19438	2021-08-06 16:43:53+00
145	5273144	0xaddede6dcf49cfaf40cae87c5c1045df21dfb5d1821b727375324b23f00a9a9d	2021-08-06 16:44:08+00
146	5273145	0xdba2ea7ab64f85adee09304dd4abbff204cbcf61cb4dbb0f528488b1f26e3282	2021-08-06 16:44:23+00
147	5273146	0x7b57d4ed112fd445ddb83c4e6089e4043277c8284d976b0bcae19a0eaed41e00	2021-08-06 16:44:38+00
148	5273147	0xd1123870296493a2df851591ab6094b35eb21c336f103f6969775a7eea033b65	2021-08-06 16:44:53+00
149	5273148	0x228dd0241bf017bc5a055385384dd02bf25c69169d3fabb4d3b531ad877c9f71	2021-08-06 16:45:08+00
150	5273149	0xa8945d5fc100d41dad666222d541bbd84bfebf7e87531efcc21ead804b575306	2021-08-06 16:45:23+00
151	5273150	0xe635ee247e6e079240d8dfea4c636871f6a86686bd82113a45b5117a36e716f7	2021-08-06 16:45:38+00
152	5273151	0x3e13d9e9ca0a258d5be4b8bd7a92b3891482784773c8eca5a8f178dc1be41b8f	2021-08-06 16:45:53+00
153	5273152	0xaf0d9242b69228540400ea40ac5a1f68b0b269034ba364bec665c3fc6de08d10	2021-08-06 16:46:08+00
154	5273153	0xd4f44fd38d0aa4b46e90461ecf72a3f06c7b75ac08c79e703d4e3038f8ee688d	2021-08-06 16:46:23+00
155	5273154	0x43ea87a2ee1f498104320f41e493879a6a81f8068d1e1c926da837417ccfa2ba	2021-08-06 16:46:38+00
156	5273155	0xa181e50582602dd2a2f694300fc0add2c51365705823bc13e50517003143c9a8	2021-08-06 16:46:53+00
157	5273156	0x2c36a6647eae6f2fcead1da157b03affb9ed67ec11e9a6208ae4db58c937a478	2021-08-06 16:47:08+00
158	5273157	0x14e7635c4ad88a6396a0bb1bee96682b55612e547e4f40b3f52fb153b5c10216	2021-08-06 16:47:23+00
159	5273158	0x9f81ca0074d1ac100dfc385b3d272535504d042e104f81af04955ad9b67aabe7	2021-08-06 16:47:38+00
160	5273159	0x15117d6598600b219313f100ad0b3c39baea93ea17c096cc6ef5ae14413028a1	2021-08-06 16:47:53+00
161	5273160	0x88093ce3fc958401e5dc21bb74d203fe0b86579e596f5c3f251d28cd4869e947	2021-08-06 16:48:08+00
162	5273161	0x3d9a427dead72a96ed3dd68dc49d3b0ddfdefc75a646cb9baaece8b34f33b9a3	2021-08-06 16:48:23+00
163	5273162	0x2601e1f2ea9fa89d907092c70394644bbcc6b8588ea9636ae8f640516b177c07	2021-08-06 16:48:38+00
164	5273163	0x2d715921a19bd3fa26873c81687a8e89052a2b3d38c96e0c450dd6bf26fe1633	2021-08-06 16:48:53+00
165	5273164	0x7e5a887c95b975d14d91e4cdd30066184d1b9a05f8920eaf79f40cbb8caebb15	2021-08-06 16:49:08+00
166	5273165	0xe40712ffe6fa988e554665d9c0ce2f9323ca37ac4f218c5b2bd3b78a695a2d50	2021-08-06 16:49:23+00
167	5273166	0xdb212eaff73fdb01658390116ca6c696eb8b714f9225d4f822dc883f0fac5c80	2021-08-06 16:49:38+00
168	5273167	0xf4443e2751b65820e39ac6fb99c373755d5f618bdc2639ecb29fc089ee5818e8	2021-08-06 16:49:53+00
169	5273168	0xb4e06ff31f6794ba3003913c7fcb7194f9963d658bb0ef1abd1dd560488be972	2021-08-06 16:50:08+00
170	5273169	0x1a0ae282e937f5a992cc98d5f577502a13c688ad1640db830c6f9ba6dc819018	2021-08-06 16:50:23+00
171	5273170	0x6403d7ba60f663c9008b9f974e85e4c448ad32e1129f46bd4c505b5b3d253b84	2021-08-06 16:50:38+00
172	5273171	0xb2f20cbd8e0ef259187db73fa1c1e7f929383c66ee2fca196adb0790c79efe0a	2021-08-06 16:50:53+00
173	5273172	0x1ef48364c46723576de9bec5bbd6c6114764becd5c3542f9157e77ccb0cf6673	2021-08-06 16:51:08+00
174	5273173	0xbb1a6214821ae5f1b6fea9f2f081228b6bbcc9b7f843dd92cb994fd928ff5b79	2021-08-06 16:51:23+00
175	5273174	0xbcb8bc76d8497efb1821f589ea013216c8fdadf438955c0aad4b0fcc84594113	2021-08-06 16:51:38+00
176	5273175	0x432c8222e3757eb58bedc64c9342fe733d88c0fee050da7575cc3923e53a5788	2021-08-06 16:51:53+00
177	5273176	0x9421592b9053fa99523991082aaf72e4c4c50636bff4d18c514761ef640ec303	2021-08-06 16:52:08+00
178	5273177	0x99bbd33eeaf500fa94b1851963b812f222a323e78cb739043a4512563363060d	2021-08-06 16:52:23+00
179	5273178	0xd9c3de987369a17684748718ef49bcad843e57ea807737d72da355a650a77963	2021-08-06 16:52:38+00
180	5273179	0x20501b302c87adae6227b018a9867993f4e1cadb91df3c3829387177b2bb6612	2021-08-06 16:52:53+00
181	5273180	0x43d0f9260847dcf4e4b49d1aff7de0605644655784ddb5f74eca0c97badda45b	2021-08-06 16:53:08+00
182	5273181	0x665e2cf89f6b75be851620f8cf91417ae84be369e6753b3939954c136313d9b5	2021-08-06 16:53:23+00
183	5273182	0x3b799b70520c33d52b0ab3846bdb0913c169087284ace59cfd8408e40c21f712	2021-08-06 16:53:38+00
184	5273183	0xeed11927386378979e27230f0d9676bbdd5ace3716905de40fede7de10193cbc	2021-08-06 16:53:53+00
185	5273184	0xd7840ead89aef5656e2021e527f1e713ef22a4faef5d2f35ed424c506608b91c	2021-08-06 16:54:08+00
186	5273185	0x7a5c2d1c257d0f878ef8f59ca892cdd6cc242652ac86d81c3e3f7e406d850332	2021-08-06 16:54:23+00
187	5273186	0xd390f8450a3d79be2bc8e383dbdbe8c2d6b0fa234fab2002dabe936c18a59781	2021-08-06 16:54:38+00
188	5273187	0x450d2dbb30bbc3d582ed76e7bbc4ee60eba193c8c92e289f4e3a9abdf3432524	2021-08-06 16:54:53+00
189	5273188	0xc6af2c7b1ac0e1468ceb8253304d8364fe330ac3f9d5b8e40b29b001d1a5696a	2021-08-06 16:55:08+00
190	5273189	0x02f2934d69e5f61bd8d8ac46fd0e4a92f7caeadbf0a6ef381afa31bb45660ce4	2021-08-06 16:55:23+00
191	5273190	0x974c1aef73ae6d759788dbff63f4b6f3096a2f93f109028860a1c71d06dee5c4	2021-08-06 16:55:38+00
192	5273191	0x5ecae922708c4f9301ca5ed1743eba9aee7f36e5b4b260089590d066d0c3b604	2021-08-06 16:55:53+00
193	5273192	0xe985c992836a85e757467aef4affdb67cab80412b9cc2f695a22a271490f9b9a	2021-08-06 16:56:08+00
194	5273193	0x604a512a2b357b4b16380c699c3ae191e566f811e0eb21b5ab4b69507bde4300	2021-08-06 16:56:23+00
195	5273194	0x95b611a3bd16afdff52f94deb3878e132c98781e897ffbf14bb7038102840774	2021-08-06 16:56:38+00
196	5273195	0x6b5cbd94f59f1e73f41e2a26885ea357d228ec6f7e8d1c424cb1fc310dfe862f	2021-08-06 16:56:53+00
197	5273196	0x4ecf7852a18f640a66e3cfe549e99a1cd2c122c17697058b2e38bfd0c4826d13	2021-08-06 16:57:08+00
198	5273197	0xca9ba2fdb53a13c9ced2f7f4245c1c881bb9b7c70a6700ac751d98c514bdc89f	2021-08-06 16:57:23+00
199	5273198	0x7778467d2c461ba35f08335cf1f53a2415afb2f4dbc7a452bdaee70228eb0c7f	2021-08-06 16:57:38+00
200	5273199	0xba401fdf94c532f658ac728ba1178d891a9fbec284f5aaed83a6f67a2fa450eb	2021-08-06 16:57:53+00
201	5273200	0x1644c789a7ca13003598d0df0b45d7f971800e9d403c7d6ea64144bbbb2e3bd9	2021-08-06 16:58:08+00
202	5273201	0x5789023dfbd21f5f66bbe2d272c8ae907fc9acad2ab55cbc28a6ff5e26f0a2eb	2021-08-06 16:58:23+00
203	5273202	0xfd2870ae5233179d2cae5ddabe8bdfe6b37d7986dd6762c18bbf6b34df04ede9	2021-08-06 16:58:38+00
204	5273203	0xbb3be0a18b3bb383d7bbc50d880e5da4e1df9e3fc91a4c1a487c2ca2ee5b6bd6	2021-08-06 16:58:53+00
205	5273204	0xe9b22864e67b2aad43f8de3ea245dd73cfea56d5b2790b1fc1c7644bc48bf96d	2021-08-06 16:59:08+00
206	5273205	0x1bd175b9c2dc955bdb225e8bb65ddba5956c4ef5e9cca4c7f4f6ede6738b21ce	2021-08-06 16:59:23+00
207	5273206	0xf5f3554c3d6d0dd4e32eff2e73608b25097a8e9b827ddf907ed333877199e58a	2021-08-06 16:59:38+00
208	5273207	0x48675c22e419bc7609ac5dd65fe020073b8a87e965f3d4d2b6419ad944477d73	2021-08-06 16:59:53+00
209	5273208	0x95400ec6279a9c1c9c70eab0cdca41b46d084bdab90beb53ed907db8ec3bb61f	2021-08-06 17:00:08+00
210	5273209	0x1aa78cb77cdf5a0243be3a5d90209809acdbaaec259b53ea35308f43c62e15b4	2021-08-06 17:00:23+00
211	5273210	0x69a5c252894073e3e87b4063d63c27951cc11be49044589c123b25be12014309	2021-08-06 17:00:38+00
212	5273211	0x36c45fb9318ef3d6083d6697e037cdd808bacb11415eae5326d8b036cc813c7d	2021-08-06 17:00:53+00
213	5273212	0x5f6e0093617dc56155716150621ebba456d6f264b6c29d1f0eb73c70a60cd353	2021-08-06 17:01:08+00
214	5273213	0xef3030a5a446a4bddc370746992c8deedcdbfab91c510848aa28be4a3141e68f	2021-08-06 17:01:23+00
215	5273214	0xf0be7457b869dc33421d57702d292acd86f80423d3c92283cc5eeeb6353ab8ef	2021-08-06 17:01:38+00
216	5273215	0xb80bd1a95ccd4f2d8d6cac3dcb89f8db71fe49c883014567347a785e64bb8a24	2021-08-06 17:01:53+00
217	5273216	0x18f83699c01b9fa60b561d97486d3cb50a5b1ace4cc0d3b93ed37741fa2353fc	2021-08-06 17:02:08+00
218	5273217	0x11324969e486506634e8a06c9263126e0bbdcfc05a0fce42fc1f955300331023	2021-08-06 17:02:23+00
219	5273218	0x7846f72cbfc907c5bbbaf635e817343d4efa6a32bdcb979ead945fe76dec143b	2021-08-06 17:02:38+00
220	5273219	0x076782c5e51e92dfedaaf513925c91c5a1cfc0d469f8261984a2c124189d544e	2021-08-06 17:02:53+00
221	5273220	0xb735b4e33af550a1ec206dfed4d23f21c2b2434fac7558480d623a722748aed3	2021-08-06 17:03:08+00
222	5273221	0xa51f03a304d03558ec148bc16c3d80dd426887e90a66a465c6c83d996f3f356b	2021-08-06 17:03:23+00
223	5273222	0x32ef3706d5beb22d1f7154c81924798b8df80bf3b80d0366231d9e738c8a4e41	2021-08-06 17:03:38+00
224	5273223	0x87b4237d99e21cce48b8751dae14574905750dcfa6c56abc3aff42af512541e8	2021-08-06 17:03:53+00
225	5273224	0x762c8f9d6e2556e49c93cd5f3800d67e9c3ce7470cffac38ea51f5f372069253	2021-08-06 17:04:08+00
226	5273225	0x1c5f09e314d3f3a2682fcb52ba9e9ada8e167cc5ba2d68c6a7d91a3736a32bcf	2021-08-06 17:04:23+00
227	5273226	0x9a68808b2d66f82acb458bfbff87883a4701e9c7ea5961beb306270c2605122b	2021-08-06 17:04:38+00
228	5273227	0x013a116af40cdabb02f89910fc3ab2fb8d6a35be9b42e24c90380ee97be3e7db	2021-08-06 17:04:53+00
229	5273228	0xabd4ba4a40dd3e3ed75dae1913bae51614fba9783a10d4101761dfc0a18d9b5b	2021-08-06 17:05:08+00
230	5273229	0x34deec49533b7e9b4e51b00c5789c225369f4daca14212a00b7532cbebd6fda5	2021-08-06 17:05:23+00
231	5273230	0x232f777a9bfdbe65d3c13fc4014ec4c1f63861bbdb70eb058e51784a5639184f	2021-08-06 17:05:38+00
232	5273231	0xd03ecb08fbeaf80fb17feb170bb582adbaad09b3982d1801dc1f8699c9886b8f	2021-08-06 17:05:53+00
233	5273232	0x99e5cd9a1bce3bf32730e38765738a8e273f3dda2d25c1ead0a33a76bf736d4d	2021-08-06 17:06:08+00
234	5273233	0xad82fd49e8aa9c2d1ae7c4480794554e33a5a9928f19b1d16820a60fc8925f2f	2021-08-06 17:06:23+00
235	5273234	0xf0eac33bf60409d9bbbf03ee18f4706095c897e9504a33eb72c126b2b1683a4b	2021-08-06 17:06:38+00
236	5273235	0x15ceb897a7ec2c8cb92befc18162b3c57447778afb19c2ec18b34d2fd38662c1	2021-08-06 17:06:53+00
237	5273236	0x8d2b158c2394610ee7c12fe0462bbbd84190bc0698141a0a5a24423fd5906abc	2021-08-06 17:07:08+00
238	5273237	0xbbc8ab258b480152a1eb31de28d389c8ec7e559aa77823d66dc2362489872325	2021-08-06 17:07:23+00
239	5273238	0x4e0c869b7746efd1a6c13b85a1d3fbeba36df80f91f03d7241ceb9706fe44060	2021-08-06 17:07:38+00
240	5273239	0xc47febf68f7e95323e99f35c7849ec3b55854b3f4ff7371c6f69aac36c07a386	2021-08-06 17:07:53+00
241	5273240	0xfff2fc7d747c4e90a4ea237ca1fdb674dfbf3c334f28845b1197eb2aa5d10664	2021-08-06 17:08:08+00
242	5273241	0x07dc89ef8a4e4a61ed228223f7b8042f2ecdce491bc15c44d764574649f97a22	2021-08-06 17:08:23+00
243	5273242	0x95da801e2854e2f8a94770dc021e9085b7dff408f77593c0b88271f3e98772a5	2021-08-06 17:08:38+00
244	5273243	0x0bfbf847eebe9c051ae2714d00516b9611771dde7da24e8d849fa97968e36558	2021-08-06 17:08:53+00
245	5273244	0x69ef54f57c4074183445c1199ad35461c3fe4a988e933f9a6ca19d426b389eea	2021-08-06 17:09:08+00
246	5273245	0x941de56cad5338523b3666dbd47b47bb679b0c47015aafbb0334b42683349456	2021-08-06 17:09:23+00
247	5273246	0xc0739ef4299273cc7080b2588c59c294727f2d95432ee5059aeae8a465594d05	2021-08-06 17:09:38+00
248	5273247	0xddc81ece217a3887a2cff16706903a3c99425081801b09e306a783726b572b39	2021-08-06 17:09:53+00
249	5273248	0x3a0b5031ae58d937a9fe57babf843a1745accda931bf8db5c19197d4009884f2	2021-08-06 17:10:08+00
250	5273249	0x5572deff2abd4b86e56e2ae176bcf3543eb11921459e4386856c0a6e6db082bf	2021-08-06 17:10:23+00
251	5273250	0x5299bff4b7a673ef496da551e67f2158d21640a13af13f06f7f1d4af11ec0473	2021-08-06 17:10:38+00
252	5273251	0xcb0ff08e01700f84a8c92e64f44667d8f1cef634d82132908216f5387656f6b6	2021-08-06 17:10:53+00
253	5273252	0xe4a3bbb70916599f1f31c30164d52b9d9b54fb6edceced2fdf7d4ce2db22e56f	2021-08-06 17:11:08+00
254	5273253	0x96879aa24a32527f85fa6447d984c634bf2242ff9843732abb6c7dbf7a2cc567	2021-08-06 17:11:23+00
255	5273254	0x198cb7b7173d3270ed32afe708939b173ae6603041c1032e83d9a207a8262997	2021-08-06 17:11:38+00
256	5273255	0x0d888cfbd7abf550eee517a1dd3c4f7ee089afeaa1540b18cadc9805e5a6d0d7	2021-08-06 17:11:53+00
257	5273256	0xc7c832eeaa019529e7ab0e58c9fd7cab67f08ccd464cfc5374d88b7af431199f	2021-08-06 17:12:08+00
258	5273257	0x08a7981183195975b0686a8059d5fbff95fb2845fa1f2eb2d4fc4cf2f52c0010	2021-08-06 17:12:23+00
259	5273258	0x99f6e94f0f4155602df18d16dfe2aca4fc9bbaf6d884de7ee7c24a0fd9df6ed7	2021-08-06 17:12:38+00
260	5273259	0x1f4024c86a4edcca48906372cdd30d9e35927e8f0d69e2df8cef602a5c8ee564	2021-08-06 17:12:53+00
261	5273260	0xc8f184b0e2ec401014a1e84d2b80e7f4d729a02eedff2d530600cadaafe210b0	2021-08-06 17:13:08+00
262	5273261	0xb36ce779e1b8b41628bfd46b1e266fb2c7e643931f1fbfa93c0a0d1c3d053e6a	2021-08-06 17:13:23+00
263	5273262	0x9f9a818f9eaf1b05876d9394391e74cdf39492ae6397df85a8be9061e734f8f4	2021-08-06 17:13:38+00
264	5273263	0xc2888d2cf92cf4fb1223dd30e0f79b932b90f0f52b3b6ff056017095c837cefc	2021-08-06 17:13:53+00
265	5273264	0xfc8c4b880fa343ef900ae31d3ae6c6734927dd10567ec0395391d8eec266c522	2021-08-06 17:14:08+00
266	5273265	0x63a0425304ce85cc28d8cda6da6d8c8e673463fa512509ac81b7be4bd727a55f	2021-08-06 17:14:23+00
267	5273266	0xb92cbab864799d95606a0666af65242e4f29be500058358050dd9a972168a0e1	2021-08-06 17:14:38+00
268	5273267	0xd310f4fea2224bb7c17f2499840f64844d1d3e7e24de6764c53907b7b422a469	2021-08-06 17:14:53+00
269	5273268	0x4d702752e582e45ed80d4fba43e00c136a4620434a3eb3de17474123775f8b11	2021-08-06 17:15:08+00
270	5273269	0x545562b675fb1839a07d7c1847fc024ef9193fa7fd6c36a955823b53d04cb73f	2021-08-06 17:15:23+00
271	5273270	0x418e6583aa57cb20dcbf8bbad480b0b47d23b4de57bd1146891e62cb5e63a965	2021-08-06 17:15:38+00
272	5273271	0x5fa8becc1f7b8331a007d4a040ffe76c349bf03d078ecbbae03a5cc696579b52	2021-08-06 17:15:53+00
273	5273272	0x5e49dc0530317a662eea3a8282111c75ed4369cbfb52a6df717675c2b2bbb18a	2021-08-06 17:16:08+00
274	5273273	0x18cb0f35ea116070e75ede7164d206fb7c94e5a8551a3b3a40b2626820c9b4e0	2021-08-06 17:16:23+00
275	5273274	0x50eb1c5b4a805c1605dd3f15d29559976ae9db71ba76ceabf8596d1bfa7c4d18	2021-08-06 17:16:38+00
276	5273275	0xfacad0896e90fca63acc3fabcb4b79c13d2891945d265d8c7a21ced669eb98a1	2021-08-06 17:16:53+00
277	5273276	0x53400fb95280b03ae22f8a24535b50b0de06510e2f5298540f765571c1c0f41b	2021-08-06 17:17:08+00
278	5273277	0xf82279c60edb80fb9d0c5f2ce88c442f7507d85d613f79f8b73e95a9ba9721c0	2021-08-06 17:17:23+00
279	5273278	0x899e80ee514a4298a3003af32506f05417213fc6711e35c43ef6b7144208f7c4	2021-08-06 17:17:38+00
280	5273279	0x9ea90ce85b9a2fb6581cc43938ce7622fd110826b7c18ed7aac3b55009171a24	2021-08-06 17:17:53+00
281	5273280	0x475c380752b0cd7ae6f8534d1ace0f39263e2b415e8ff3606e0ebd11a357980e	2021-08-06 17:18:08+00
282	5273281	0xf0aba9fad70f6bcfea27ecfa969d1876e9280ebb28acfca721eb376b1b8b04a9	2021-08-06 17:18:23+00
283	5273282	0xd71267c1d8bf0b76539f83f405dd39d5ed2d20009b590796c789c9830bcbba11	2021-08-06 17:18:38+00
284	5273283	0xb25613a5ab59bf04133866f1dfc338c4a5877c46a448bfb4cf7e86d40e838aa3	2021-08-06 17:18:53+00
285	5273284	0x189e3a688c6aab0a7272b02871061cced55d712b43259eba719b6d25e591812c	2021-08-06 17:19:08+00
286	5273285	0x758a2ce2a4744c661ef05e88e87d0dce2e91eab4d894a31e56635c6be57b75ca	2021-08-06 17:19:23+00
287	5273286	0x640ec353214f5d499c1fe4f513e871b33bbc59260f6fca46129fe5778f347db0	2021-08-06 17:19:38+00
288	5273287	0x01e2837c36078225e1a0befab2e0391ed748e06480e79d5617aa41b6c6bb7fef	2021-08-06 17:19:53+00
289	5273288	0xb839e78656fca06f339a42c73cbdcbbee8fb86994675fdb2a16f9907f8084b6f	2021-08-06 17:20:08+00
290	5273289	0xa23ca83af4adbefd84132b248fc924971ee3216c43e9119a2aad2b11affe1fbd	2021-08-06 17:20:23+00
291	5273290	0xb2a29b65966cc40b2a00c8c052dcea7f3376e2f39e070c668ace978b5e8c74d0	2021-08-06 17:20:38+00
292	5273291	0xd36c926c0997da31157d2558b844caebad9d83f3b2df8db4963b44dcd0bda49b	2021-08-06 17:20:53+00
293	5273292	0x4dcb9982f80e3277775781363ceb0bfa4e05a17510b947797d75d529fe6eeab0	2021-08-06 17:21:08+00
294	5273293	0xf21033facd19a1bbc7f1f6a5cac68b55228ef1e13926bb39039a8be0fe4e6885	2021-08-06 17:21:23+00
295	5273294	0x1636ab11273e9704b3c1c3051f30b823f87b2d8e0a1f1694c60b27cbdf8a989c	2021-08-06 17:21:38+00
296	5273295	0x9047b1eacb7ff1761582681061b3564e40183e8268b08280f73602ef7e43f0b8	2021-08-06 17:21:53+00
297	5273296	0x5ce09bb325815ecb29e709f38ddf71dccc6d2cc570a07a7d6d777a3f7370f8a7	2021-08-06 17:22:08+00
298	5273297	0x403d09e71b376133dfc340c516bbcfe95928116e07953a6ec19305222c71a517	2021-08-06 17:22:23+00
299	5273298	0x005fc9b6cb5f9ec9c37b457efca4e08aaa922a5b5a6537780dd137766941fc68	2021-08-06 17:22:38+00
300	5273299	0xa4bea5270943aaa81eac45255c879598cff10024932f7bd29511c41b5a249a83	2021-08-06 17:22:53+00
301	5273300	0x0c140a2638bb6105301892e90fcb72174262d9f909cc12cb18f5ea5fdd05b5b6	2021-08-06 17:23:08+00
302	5273301	0xc48960fe5b6df60d10bebed3ba1bd425376b76da5a6c6f7cee398a92c2379260	2021-08-06 17:23:23+00
303	5273302	0xcf505153ee70595ea6979830902980fc71687af8c02c17a5d2f444ee2ab9b80c	2021-08-06 17:23:38+00
304	5273303	0x160ee44d77be090e2108315ce3d773c0a0a1148dc2aefa6eec52b2f7ffd3755d	2021-08-06 17:23:53+00
305	5273304	0x77584a85d6b034b685c57d1d466881f7deffc3b164f6e077f78ad7e1eeab8d14	2021-08-06 17:24:08+00
306	5273305	0xc5686868aad6e570096e4a5ab6ec6dac7f552f0822c3b8e07ba1e1ede1a36bb5	2021-08-06 17:24:23+00
307	5273306	0x0cff337153d18368e5d941008dea804c7ef3d6625454cc73d3b4340f51cb2af0	2021-08-06 17:24:38+00
308	5273307	0x1462800861e585bee5b439248e2c628dc49ca5747f2d63096f8cb837e4de64ab	2021-08-06 17:24:53+00
309	5273308	0xd77592ee0bec96ecc097da7ea23145e34a1946a3c10b18f8b847a945a49be994	2021-08-06 17:25:08+00
310	5273309	0x4936305b4d3374128b151db8d89bcbfb28274a70946cb1a44c67c756f6f66737	2021-08-06 17:25:23+00
311	5273310	0x3d1ee8d08b7569c6a588c2949e131c7a7c6567be11695a3d848d58d857b7207d	2021-08-06 17:25:38+00
312	5273311	0x5f9c2e1ac8a19f409ae7fb220861295cc296656e05493d37ebf6bfcf32172053	2021-08-06 17:25:53+00
313	5273312	0xe477aaa3e90b25a58295c0b7e3a3323aebc245343351d045adf8f8293e2f0b0a	2021-08-06 17:26:08+00
314	5273313	0x1be17e66b746eede2ffd1186babff59459b85ea3b8ca4e55a09a58ae5e4719f9	2021-08-06 17:26:23+00
315	5273314	0xaf3584aaab859a5525310c862a7b68d52f7b39b82c35749d51824c664e98ac20	2021-08-06 17:26:38+00
316	5273315	0xc731130e68aac7ece39d6a1fd28bab5a4d59452860ffdc67aadc1906e279b4e7	2021-08-06 17:26:53+00
317	5273316	0x90d7ca3d7671185412c20c7d86d73f6f420686d04348089529adf7606bfdd1a0	2021-08-06 17:27:08+00
318	5273317	0x64495b607a06da2c0857a37711ac338a3b5349f789207050ae5a138742e43e89	2021-08-06 17:27:23+00
319	5273318	0xbcfb5c00744bd84f2fe0cecfe1b77423e6c738212ace774096c3225ca7d1171a	2021-08-06 17:27:38+00
320	5273319	0x146a7524df604bfa3fe03d7fecbcad3c9e17b6c3788de5ade1bb3851a58a15e8	2021-08-06 17:27:53+00
321	5273320	0x6c20694d4f2a34207aea8d90d336c550226cd0729866adafbc0108eb74df508a	2021-08-06 17:28:08+00
322	5273321	0xc07bd06b9c4aad5f816a0894efce4e0645d026437102e88d2c72c7037ff63f6d	2021-08-06 17:28:23+00
323	5273322	0x405b2704d7fec305e9cedb3ed411495bdb14e5178926ac4e79281bfafc952906	2021-08-06 17:28:38+00
324	5273323	0x92927cf60edc5259cf892f0c7917e2dc56da6c9386506f3cc2f5bb23adb38119	2021-08-06 17:28:53+00
325	5273324	0x92de1dd495e7d60197bffe9156f088ed1b57bf626c3c0eb77103ace53ad557ba	2021-08-06 17:29:08+00
326	5273325	0x1f0dddbb3804492ab61cd81dd64cd87633e9abef0de36b75b949d8fe5dc67108	2021-08-06 17:29:23+00
327	5273326	0xbd5283702c38168ea79f6247e752d506328fdac1b726b40ab68654fb493cb047	2021-08-06 17:29:38+00
328	5273327	0x23c8fe37003c0afde71d88910b985bbfe284a27806f283824eebc0c2efe17d1e	2021-08-06 17:29:53+00
329	5273328	0xd526a2e9edb042c5b3904017d5aa0f10a4ffb322ce052da1dd2aa79b0c0e8594	2021-08-06 17:30:08+00
330	5273329	0xfdc944d250df190ee1256f33309f5e6b06fcac731802e298163b3bad7394ae3c	2021-08-06 17:30:23+00
331	5273330	0x2a6b75faa700a2bab9ca34635710706e8cefbefbdcbee9b8cd486eec50839eb1	2021-08-06 17:30:38+00
332	5273331	0xd9e6682e2690d9df96bf1c297c2ed399dd0860bb051e05ef8a3224a8aa0d917c	2021-08-06 17:30:53+00
333	5273332	0x9b20b7f6fd42830324ce5290b1f948defea34f14334aeecf47555f8a792e5e72	2021-08-06 17:31:08+00
334	5273333	0x48f134746c990dfb695576d6d94b9b75adc30da1c74958efe559152325a97fe9	2021-08-06 17:31:23+00
335	5273334	0x3e9759e6d377e73b09ba68712fc8641bb09678729aba89dea319cc9e2b922cca	2021-08-06 17:31:38+00
336	5273335	0xd9bb056ca6c424c39782956addc460170d41c6fb4df5c318660db11be94f43a6	2021-08-06 17:31:53+00
337	5273336	0x50817f4b46340f7fcaa2f42bc1eade25b76e7decc7a5084372ff17561062998c	2021-08-06 17:32:08+00
338	5273337	0x4d55dd1de85119d4cb9677c97549db36f85bdf001d439844d5ea679c908dd929	2021-08-06 17:32:23+00
339	5273338	0xc1a9e6c8d631926e0ba9d75f7502e572630612ff0912e4904bbd8986e4c23ace	2021-08-06 17:32:38+00
340	5273339	0xe0cb70d247035c3254d8c39f23769d80eafcf9139c716974ad18c9d05728c8b3	2021-08-06 17:32:53+00
341	5273340	0x53b7c2897f3cb3f6a72f1fb1ed7a4e7787b809943a534e0da99a2498444426bf	2021-08-06 17:33:08+00
342	5273341	0xe261edc49022646267192c04333d76c6ded123309acb2c9b877e7453c7cf35ea	2021-08-06 17:33:23+00
343	5273342	0xafcc54cbe8989c62918d8f4faf7abaff7eafe757c6591aa772b3dc1f6959b69a	2021-08-06 17:33:38+00
344	5273343	0xe90e315a1ce3b528e3e2f2f9930521496c0211127f2d137786f587f191484e8f	2021-08-06 17:33:53+00
345	5273344	0xe888a53b49d907b7227dc061fc40f04a9ca60d8ff14ba00505d7d6466c6be7f9	2021-08-06 17:34:08+00
346	5273345	0xf620b3d74cd2cf68bdd6c8c53eba2edd9c83957ae4ffead2b948f4ebc0d5047c	2021-08-06 17:34:23+00
347	5273346	0x00d336cacba922b0a6661f6f7dd542f81b2aea989b7bc4e7611249e08ed12a84	2021-08-06 17:34:38+00
348	5273347	0x1a81c64d8d5c2d48c6c68e858734cb1b5384befdce40d2f5995e2d17cb58f8ba	2021-08-06 17:34:53+00
349	5273348	0x063e505a5190ff008e39fbfb8e70a0a84112a19333cc48cfcfca70e7493ecf0f	2021-08-06 17:35:08+00
350	5273349	0xeed045667c1816c2c212a2f225449f762b6619d0fba5d7756e2fd37601c3d93f	2021-08-06 17:35:23+00
351	5273350	0xd83a17ac61525d91f8bc84f4b559e36748631a0d853efeb54923934bc8430683	2021-08-06 17:35:38+00
352	5273351	0x921956ddbf424f06576b5385915871615919a3037bcd1d4288d3297e65ce4230	2021-08-06 17:35:53+00
353	5273352	0x2512864e13be3b04fda6234b1fc522b98eb2b62f4a53282546b2a4df88190472	2021-08-06 17:36:08+00
354	5273353	0x555c0bf375ffe8dda7818cb4b36f524466716189531a1988f16523508372bc65	2021-08-06 17:36:23+00
355	5273354	0x4421825568a7f3ba569df3c7d2130f67bc6414197397704d45b4420481fa1f41	2021-08-06 17:36:38+00
356	5273355	0x0450bd773eda21366a796a650fc554ec58f9eeff9e46e59cce9310cfecbb24a5	2021-08-06 17:36:53+00
357	5273356	0x2b05ee5f8b9eb1eb953fe5dce3a0a2456703cb714e0adace63059f8b2f34ffee	2021-08-06 17:37:08+00
358	5273357	0xb40b0fffd565215c6a52450b36115d3ccb5cd957c8399370bc528fe662829c84	2021-08-06 17:37:23+00
359	5273358	0xfb804f4ca635e37897bc5a225a88f8288fb131e68389db2b5c841d41488cf591	2021-08-06 17:37:38+00
360	5273359	0x287af1f8de304a62440fb7ccc4940d877cb2fbf4fd90491360408a3511c8fa88	2021-08-06 17:37:53+00
361	5273360	0x16a2b2b8331aa8cd95ab0e6a5c6536f9b33e4b9f0932bafae1f817b6688683c4	2021-08-06 17:38:08+00
362	5273361	0x9447cae21626222e12fbd6c35490f4edca1054239e542bbfe2e113cf858f1522	2021-08-06 17:38:23+00
363	5273362	0xe3c9823226741a329f31d890bac48a9ce2dbaa7c5220b54a9fbd490ce6c37ab6	2021-08-06 17:38:38+00
364	5273363	0x7c320b16881ba05693c5baffc2e8341d792cabe2f82643fe75fcee779ea882a2	2021-08-06 17:38:53+00
365	5273364	0x89dec67fe2d7485f97d8384385afd5bfbc19d324f1b9c4dc9260ccc66a5ba323	2021-08-06 17:39:08+00
366	5273365	0xf3c43641c211a3e1027b54c94f075730487bf0eaa2619b69a8d00d21180ad288	2021-08-06 17:39:23+00
367	5273366	0x7e4d3b18a836f2e739a6c91ee5fa244f7b0cda83e5860effc665026ab2d247fc	2021-08-06 17:39:38+00
368	5273367	0x6abad8117639aec978586ade574883786f7dbe80bfbd19112cba002e3a1eae13	2021-08-06 17:39:53+00
369	5273368	0x60760f2c530b81d375af3b051e6a69cf5536c644883ca057f64fb7c996102dd9	2021-08-06 17:40:08+00
370	5273369	0xb24d8bb8d433b690dd31911b075ee7d3b3b80565b56c635a5eab2d66707fabc5	2021-08-06 17:40:23+00
371	5273370	0xd80820589f4a39709dc682be24b9aa55e8675cea7aa683a35991c41ca774b512	2021-08-06 17:40:38+00
372	5273371	0xdbbe9e7bad0cbd609092aa14786c813f8a80c6f7e9fb6ee5e68644feffc08efa	2021-08-06 17:40:53+00
373	5273372	0xdb3940190b591ba52d39fbfaf4c855d82ed0f237bdb7c90dfca2855eaf9e6d3e	2021-08-06 17:41:08+00
374	5273373	0x9a1a47eee5066fee0b5fd353d9c87154f94e5860d09d7aade22cf241c60acfb2	2021-08-06 17:41:23+00
375	5273374	0xb22a013f1f1e738d383e6f48f3beeacd0661eb227dd7e62ca3f11a6b82ed257b	2021-08-06 17:41:38+00
376	5273375	0xdcd383da5c56f0f8121863a770a7aeae8e0df09e267b02492b33ebdc1d7ebaf4	2021-08-06 17:41:53+00
377	5273376	0xfa5c4064de8ca6b860b1b08da84344bff8bdb29a40b7b92ab3d30f9faa482590	2021-08-06 17:42:08+00
378	5273377	0x4c830bcef1c3cd08af2fda48b72346c2e794d87edf01d01b3ea3b3b4321d56df	2021-08-06 17:42:23+00
379	5273378	0x090cdda031f5d65d5320490ac6482cde35bd2cf0fa2910c43779c0033b6bc524	2021-08-06 17:42:38+00
380	5273379	0x64fee1b8b2f93999c206ef29e74a2e8335cf9c10e05fbd43a480e84f8dd05588	2021-08-06 17:42:53+00
381	5273380	0x0386f3521264a38e1add6e60b3a584ff39744bc7ab0eaebb9c6b3ecacbdace81	2021-08-06 17:43:08+00
382	5273381	0x5937b916abd5fb8ebf876f99c6a17a70917241f7e0cac3ef68f93f8717c87bbb	2021-08-06 17:43:23+00
383	5273382	0x2b8fcda753e16e0e0083202b84cc2d0a4ca0f88b52832210f404e12377ffcf4a	2021-08-06 17:43:38+00
384	5273383	0x2fe8b06ce6adffb7929f7fc120917747774d70190689f7aee2b547cbf9b1e0f8	2021-08-06 17:43:53+00
385	5273384	0x5e8fb8d9bb64ceb0401e41c81de2f3f4cd9461c8db998a953137f185a94a5c72	2021-08-06 17:44:08+00
386	5273385	0x7875e6a66005a326dc7b074b840517fe798cb53b17513577a71f3c8dd6030ccb	2021-08-06 17:44:23+00
387	5273386	0x21e2901021333b4f90593301e6b51292ecd648665714d58caf53f87e5fc2fbf8	2021-08-06 17:44:38+00
388	5273387	0xaa3aa63c52450992bfceff21a546463b1feb290d9fb55c9e9ec359617843f28c	2021-08-06 17:44:53+00
389	5273388	0xe5d20057c359cab38017f03c780815ffa502d7301bf8c4c6f69a62b2cf455c08	2021-08-06 17:45:08+00
390	5273389	0x8349df0002654734a9b5c3c69f2c153f20035d863c1ccf098684690b6db60d55	2021-08-06 17:45:23+00
391	5273390	0x619215b224136c6c7c31008a84868f54ccb16b55f7f4f2e3680d4bf6480ae271	2021-08-06 17:45:38+00
392	5273391	0x7b32a163df151d3a00acd492d9bbc614dec5cb488f42f8b96e25cf1c942d6f30	2021-08-06 17:45:53+00
393	5273392	0xd1ff9e1c865b95b2427b20a88777222fb1c89de7063c996e056bca71886c9f39	2021-08-06 17:46:08+00
394	5273393	0xdc533144fa95bca31d995dec1f9033f3a3a28f80b86bce71a26be61cf5cc3c33	2021-08-06 17:46:23+00
395	5273394	0x792755aa290608c5fe594eefa8f2949ac6398c3cf38ec352cbcda84aebbe4464	2021-08-06 17:46:38+00
396	5273395	0x456f418b2f05e4328d35cd6fcafc87856d44815371305e33900542d32f900d66	2021-08-06 17:46:53+00
397	5273396	0x9df24ae785285c52cda22578590d8e007ef2c7cdc502d0f5412f3e410403867a	2021-08-06 17:47:08+00
398	5273397	0x8956e89fa537e8359afcd7afcd44c3f26a544aa56365507b8ea86d07e3ca106c	2021-08-06 17:47:23+00
399	5273398	0x7ca9005b6acaf74e778af5b62d8f6df8fea9626b00557b43b850d0cd4470ba1b	2021-08-06 17:47:38+00
400	5273399	0x0c488536b58752f2deaa99a8140e9a428b4dc22cb06bac90c991e1eb0a6cb55e	2021-08-06 17:47:53+00
401	5273400	0x55d1980e957de73a1021250da157fbcab5d3cbc61b003473d04d8d3a2cb357af	2021-08-06 17:48:08+00
402	5273401	0x29797a526f2ef241b653da9f23f596f71a53054f1004786a44d808dc8b8e5023	2021-08-06 17:48:23+00
403	5273402	0x942d4237a1db637f1515cc9f1672300dd41afa0df54413b475ecbdb4f1c700fa	2021-08-06 17:48:38+00
404	5273403	0x277c79f70b505082777c48cdb3e46abc6396c2290035b1392bea55c5d50fa9c9	2021-08-06 17:48:53+00
405	5273404	0xf761ffa448691981b3451d66b8f4d73c50a5703053b9de1e6b52663dbf55ae1d	2021-08-06 17:49:08+00
406	5273405	0x665619567a586bc0989711eb5748776d73b9c23260df4dcfcfc5e200e2839483	2021-08-06 17:49:23+00
407	5273406	0x2bf0961c755034b5bde6376163318148ebfd6101a3481949dcd7bb6ccf405db6	2021-08-06 17:49:38+00
408	5273407	0x7891bde4bab57806f94f270db9c3550677ef5b39074dafc0eb9844738c7c49f3	2021-08-06 17:49:53+00
409	5273408	0xdbc9aea306daedb92c759b8df38b415189e9998e416a7045c86e579592222782	2021-08-06 17:50:08+00
410	5273409	0x3281c3b017aaad21f0ffb4bb9247d673ce8db02344d5a0b480039123d7a551ef	2021-08-06 17:50:23+00
411	5273410	0x5b5d5467e5173ea1d405c8d409fa52bccbe250a93f17c984e58ade163ce5544e	2021-08-06 17:50:38+00
412	5273411	0x445fa7fa6e1a6a6148c74a04fab4d1632daf5bd9fe2a01d7105e204308d816d5	2021-08-06 17:50:53+00
413	5273412	0x7c79a373720a6f1b800bd8fee4de16d354e6555555bb73731943186ce645f9fa	2021-08-06 17:51:08+00
414	5273413	0xa95c8ec669f6b8fb9c726ba345818b45ea84ca0e7f397af4e7c5b3d9da3a24d0	2021-08-06 17:51:23+00
415	5273414	0x60ef93ec689bef310c1c082bae84d83051197f7e65b857b91720785bc7eba9e7	2021-08-06 17:51:38+00
416	5273415	0xdafd2a1360964dd2d9e9f3cd2d2821e184e4b29ddc69145ab6db5f1c30bcf04c	2021-08-06 17:51:53+00
417	5273416	0x1a79721f9e9f8f5b83096c7cdb83d90c900a0a3bebfd20f9778367f73c4ad6bc	2021-08-06 17:52:08+00
418	5273417	0xce275a9153d9767a11897ddce8f28db84c7a382cd892e92e140649e138086567	2021-08-06 17:52:23+00
419	5273418	0x040175703bf19b75d524e2139256ff3624de83684b5733258ac8af835b690880	2021-08-06 17:52:38+00
420	5273419	0x1e2923d94edd7606d56cef1ab8877c9af37a59a44d2cfdcbc369dbf4b25114d4	2021-08-06 17:52:53+00
421	5273420	0x3461dca47e7be67970161f2ed5810eb00b56434cc4b147a202d6091b4276d861	2021-08-06 17:53:08+00
422	5273421	0x658da20e12724bae4143f6717398a4f28e6124eaa9b213c1f17bf63ac100d8e4	2021-08-06 17:53:23+00
423	5273422	0xb33e9f3693d375e68e15bb56f96974f1cb4b0b53d337fe55e379295b72cb269b	2021-08-06 17:53:38+00
424	5273423	0x26b6c571f9ea602807fea2ebac60499bc979fd7977470753b37a2df49c835735	2021-08-06 17:53:53+00
425	5273424	0xa022f4a0b2fddb2d249e53b35f17b2ae7ae34b7aacf7a92137ba74cfcadec94b	2021-08-06 17:54:08+00
426	5273425	0x8391bedfc53c385d1840fea1e5331deba4e77890d6bc2222c87d6a10f21055f7	2021-08-06 17:54:23+00
427	5273426	0xe5d3ee8c63d5ddf7ea7b21f5828e369df0b61ba42af64b3662c58a4db6cabe8f	2021-08-06 17:54:38+00
428	5273427	0xbba9ef160494f911ba643af1eef7a5cca0257451da2d47d9c2af11f83a1c7226	2021-08-06 17:54:53+00
429	5273428	0x21671fbded455ca88b7a4876b17ee223a4cb198842af71a8ab042a03472f4237	2021-08-06 17:55:08+00
430	5273429	0xe6e7c4d9dcfef538e4983bb107ee1291eeead110c2825e4216f2f0038802ebb3	2021-08-06 17:55:23+00
431	5273430	0x6f76e4e1e7244eb06ebde99e96730e020cb8c40986c137454283b063e61a3933	2021-08-06 17:55:38+00
432	5273431	0xdb77a419760db17098a84a703b5d3099e7d07ed985cb0ecfb3f4bcb6059fd0b5	2021-08-06 17:55:53+00
433	5273432	0xc0d8c66427649f02ecf5c0155aa1e8398a17691da8223a51a0caf592d536fc01	2021-08-06 17:56:08+00
434	5273433	0x191971609b63a43e6853158475555bbc7eb2e90e0b4293e414ea53fa5c735ae0	2021-08-06 17:56:23+00
435	5273434	0x74381c832d5fea69b207f5bdf82bd47d6eabd72382def52c00ecafe31783c900	2021-08-06 17:56:38+00
436	5273435	0xf468370059db8c29178b72d3d8760686906825bbcea8d8a101201ebcd96de4a3	2021-08-06 17:56:53+00
437	5273436	0xc22c90487c25283f38cd07604dc905648f5b24d6439ab9d95d501d2b3b36da7f	2021-08-06 17:57:08+00
438	5273437	0x12006d07e93b3e3f2d82cdfccaed30a9fea89f288c5af1478d730ba6541b0d62	2021-08-06 17:57:23+00
439	5273438	0x0874d1544a0cbdea0c314c938bda94c7a21b58c03ae7c5c07c8c7f07077667c8	2021-08-06 17:57:38+00
440	5273439	0xd70c8726e2dadc6316f7b1492dc8c7dacb1e50d16e4841f5a9b2401f408a86dc	2021-08-06 17:57:53+00
441	5273440	0x21a0b2c5ff49d23261710361d3c0f831b89ca349034a2272eb084e877fcd89e5	2021-08-06 17:58:08+00
442	5273441	0x91f3a6a31d7591fd3ccbc75187345504a1942658d390be5cb74c76546d786eb8	2021-08-06 17:58:23+00
443	5273442	0x054623213f8f9710f539df87043d59963e9265687ad6c583b8a3834eef85b116	2021-08-06 17:58:38+00
444	5273443	0xb49ae1a7c6f607690c53f4d9c90dfd372cd408cc54893a59ce6f45bbff719214	2021-08-06 17:58:53+00
445	5273444	0xf81b2d47eb26359d4c2d5982df6abc629d669dc7858acc205928946195d33669	2021-08-06 17:59:08+00
446	5273445	0xf4cda65e44f48bf105b7d8b81c045c20e8af980f08f6b13190e7b33a5fddc914	2021-08-06 17:59:23+00
447	5273446	0x135ed4be5ecdd273d096306613e9a790c326a0dda8f0a3ca8dc81693853402c0	2021-08-06 17:59:38+00
448	5273447	0x8f60737a71c01a80ce9541fc5d00f822b1faa3f4a4762be68558e28c52606d3e	2021-08-06 17:59:53+00
449	5273448	0x211b8442545a165663b81979894f8d5b5f62afa0ff3b5e0c0233c7fa43046cad	2021-08-06 18:00:08+00
450	5273449	0xee12f88acfcc881c30eeb34ee60704d30984a90c937ffa0a79f773caa1ca8954	2021-08-06 18:00:23+00
451	5273450	0x20be7f6ef3dfa5794bc92ffbb832f047912ae85d1146cc95aaea2fc9f66a5727	2021-08-06 18:00:38+00
452	5273451	0x74176fd9e199497280d33971e5a77ad2e61385c96b361d3cae849319cc4bf617	2021-08-06 18:00:53+00
453	5273452	0x2c10f599d169ca6b27e4bcd2c4709e4a8351cc3af4971b2684bcbc084d9818a9	2021-08-06 18:01:08+00
454	5273453	0x21e51212b4bdc9627f85bd30062095ec64f044032368377f4dee37085c2ab5b4	2021-08-06 18:01:23+00
455	5273454	0x1c474e16b11ffb8ed6c84758e8116333c576049e573ee4ab532dd112febb2af9	2021-08-06 18:01:38+00
456	5273455	0x012beff61638aab9a21900a8055a7bc7381779b45f13439fdd9d889552506a67	2021-08-06 18:01:53+00
457	5273456	0x3f10b0ce0f8b5624024f4e9475e2da0beef4f2f01d8e1718988d72338cd63a0a	2021-08-06 18:02:08+00
458	5273457	0x26c182b7260a370ca8ffba10c1a93a2f5e76e59c12ebf69caf7ebbb0fca119f1	2021-08-06 18:02:23+00
459	5273458	0x25fad24aca443aa0629714dbaf81a55ecc1806d6adbe3e26f21f88b84b367df9	2021-08-06 18:02:38+00
460	5273459	0x87acfd8f9706c3ca6eeb361469c95a5e4517d92e473979cefb8ad73a9febbc09	2021-08-06 18:02:53+00
461	5273460	0x0c20ac3b2c5b260764c4dbe41ab772bca5dcf6d85cd8a28157de864fa2ec62da	2021-08-06 18:03:08+00
462	5273461	0x70743c9ae2f66f7f0c3a2b2f53a8091be19fc006a45e532ee0f328dafc94ec9e	2021-08-06 18:03:23+00
463	5273462	0x283ba2cbc5f6bbada5a7668675a9ef09bd29f186632b9ab76678a3dfe7583ea8	2021-08-06 18:03:38+00
464	5273463	0xcdf3cffac518363be1c988998775fee4c3b339f181b95ded3eb467211489b5ee	2021-08-06 18:03:53+00
465	5273464	0xaca8ddd82231bb56137a9a0972f9bcfdca0ae69483177f4e476b556c198b92cf	2021-08-06 18:04:08+00
466	5273465	0x3ee29097916d6ed249e6ede6288d1015d2c120db80517ee0dd14ce0b85e0c95d	2021-08-06 18:04:23+00
467	5273466	0x17d6003e22302ed0ea3be0323ef0a968c1db25b4dc2ae83dd51b95d42f26bd4f	2021-08-06 18:04:38+00
468	5273467	0xc27c8b8f0ca942cb6321ad5c1496277cc59ac4ac1b7467c8bf59ad3577fbf6af	2021-08-06 18:04:53+00
469	5273468	0x64172884b0599813550693ae2ec8dead23223e491578c79b02239a3ab5e19435	2021-08-06 18:05:08+00
470	5273469	0xf1e8e147815cfb6570df2c2e58d9bcf4fc66f5a38fecf2b4bd0986a8d9c88222	2021-08-06 18:05:23+00
471	5273470	0x21e14241645c775d41e7b72ffdff74ba9c058f2ccd56efa45ecad064acad3b1a	2021-08-06 18:05:38+00
472	5273471	0x4a40689e6e4b4d10ae4620d5ba1841984f64b4d913553738c6b6cdae0996415b	2021-08-06 18:05:53+00
473	5273472	0x80a74217909a43e9411ccec7081c9608197732524c77af69c7e0d0dc8a2440f7	2021-08-06 18:06:08+00
474	5273473	0x0ba53ff30d8b569e21ec361342450fb1aa1cef5b3668d8ae2bf02bb8de5fb7dc	2021-08-06 18:06:23+00
475	5273474	0xa580100730565d9088661b24946864dfd7d2f4faa2d8ca4f9fd8a3dc774e6aab	2021-08-06 18:06:38+00
476	5273475	0x34e78a9778bb11d47f42939c2b1a0cd64f152110d386b71fcae5e9130772bd2f	2021-08-06 18:06:53+00
477	5273476	0xc80a8219902cc74178b47efe48563e92f76c7931c2957d04f8527789f5950398	2021-08-06 18:07:08+00
478	5273477	0x8d060080e63235a373df276933ee0949dd39eb70c7e0dcef7958f822bfb0e44e	2021-08-06 18:07:23+00
479	5273478	0x683b45b2acd17b2bb9811f986ff396b811e90fbdb81d052ed3bb92a4f9d2c7a8	2021-08-06 18:07:38+00
480	5273479	0xf745b7b048f25fcd3d4580b2660a00b458c3113dcda1363aa2c26e7acc86e2a1	2021-08-06 18:07:53+00
481	5273480	0xcb1ef130d1d840aa804685e71752dcca9478b9f4abc1875a80b2c8c5920cd9a9	2021-08-06 18:08:08+00
482	5273481	0xd2ff7cd8c9714b478797fc9c61c0553fbb0274ca67ec475f0a9e35f368acc48b	2021-08-06 18:08:23+00
483	5273482	0x0ef90939538c8b1586545bc601e2160f8c30960d3db64dddcf5739e1d7c4c731	2021-08-06 18:08:38+00
484	5273483	0x52834411261840f558d41b0331424e76ef181ce99027b179542e383b70aed552	2021-08-06 18:08:53+00
485	5273484	0x5a93523d007b16c2fa82f2f9b8863683436846184a38bc9fc470b0acc81d9535	2021-08-06 18:09:08+00
486	5273485	0x59c01e8d204fdb097ab936f96ff8177465241b53e12db646c773a10063e7ad95	2021-08-06 18:09:23+00
487	5273486	0xbd124ac2f43db7713467c0880d14626c70204e1f5fa2ee7c9e8bdad443687a66	2021-08-06 18:09:38+00
488	5273487	0xea0957fe65224ff7b619d8607397c3edd55232f76b75cd98ac665f9b0879f913	2021-08-06 18:09:53+00
489	5273488	0x61944ac5d32b0531510d46443edfbddb7a04900bf4ce5b90be6f895020c4f0a8	2021-08-06 18:10:08+00
490	5273489	0xf65083ff46a95f0603ce89033ab54a7a23fd29b1aaba1bce130893bce0ab32ac	2021-08-06 18:10:23+00
491	5273490	0x854162d48074d3a18ece85a44d03bac243f9f436e665f3f3680a21dfa65914b7	2021-08-06 18:10:38+00
492	5273491	0x7f459191b59e5b6e5886f12ac6c049af8c5f697262054d22f2d5da6aa053bf9b	2021-08-06 18:10:53+00
493	5273492	0xc4ab17ad7ccb4e554932f80c35933de3dfba0fd8719c1cdb1849a6bd1a2396e6	2021-08-06 18:11:08+00
494	5273493	0x7ba3b9122f84b5a354bfa4fedd569ef259889afe5e175087eb33d7d96cd4633c	2021-08-06 18:11:23+00
495	5273494	0x9135cad19e4c303c4f037f8750162d6c171d41ad62ae78c0da7b7ea671d984bd	2021-08-06 18:11:38+00
496	5273495	0x7a42b9012b64ea6b4b5d289c957ea42d080227a406cdf7e36719da82b0c1b31a	2021-08-06 18:11:53+00
497	5273496	0xdaa19345d0a00f8ce9d444ad25698b56595ea92beb423bb43f71eba86914856e	2021-08-06 18:12:08+00
498	5273497	0x3f4f3bd0dc65602b60d03207f9c040bbb8206f320d9b5fa7a08a0fea005711c5	2021-08-06 18:12:23+00
499	5273498	0x59d809a13e7cf1206a26a1af1f5b26a5c50862765126200539a784b88333204d	2021-08-06 18:12:38+00
500	5273499	0x6a14b21cfd5c9a84f61f7668e105b68aebf42500eaf4028a3e1a3578a98caa40	2021-08-06 18:12:53+00
501	5273500	0xcd9463d766b4d0d4e5e72b9484e86fc9efdeaaea15a5b165188f8ed45dad1ab6	2021-08-06 18:13:08+00
502	5273501	0x6956a96d912a6adba1cf6aa81317ee82e235a5c90cc8c4c16e7d18ed6f034aca	2021-08-06 18:13:23+00
503	5273502	0xe44068c2d61e75d258e9c2a3c837cecd233a4ffecc7a046781ebccef7490b910	2021-08-06 18:13:38+00
504	5273503	0xf90a5d1971d725fcd687fcbdf14e9a20ed7fa687963e81df770f565f4d000089	2021-08-06 18:13:53+00
505	5273504	0x2f973b626fd85f757b828c0f5bd011477f6d53b0ca5fcd68b7125bb7c96b006f	2021-08-06 18:14:08+00
506	5273505	0x389fe905382eb291467e393420ac34ce35409fe167aea9cfa07e5ac9f65e5165	2021-08-06 18:14:23+00
507	5273506	0x3f58ceffebb880a60b8f9637770b779579fde35588ecfa82b1db09430e1ab449	2021-08-06 18:14:38+00
508	5273507	0x320ff416d1c345d1c30afb95223c7ffbf7c415048852362c1c5e1a96f435740a	2021-08-06 18:14:53+00
509	5273508	0xc7b8347439a41914dd31ee85d49c72a18ca25c1bdcc9f2318379f1d695b47902	2021-08-06 18:15:08+00
510	5273509	0x326649da617960de9a0fd9864a54664f24f1e237e1835727dc7393f6f43c140d	2021-08-06 18:15:23+00
511	5273510	0xbb7bd27c19f59796c77f73c7c056d539e20316820d07e0780bc99db00f3f8131	2021-08-06 18:15:38+00
512	5273511	0x74ee8df220e448349401e33450ca674e58a97068e528fdac1ff86e2613d0cdca	2021-08-06 18:15:53+00
513	5273512	0x0ac2543c9a97b445cbc6f0249bbf49febb6f27e6ee1e4ed57d41770b55d66acb	2021-08-06 18:16:08+00
514	5273513	0xf8f7fac22c5edd97d1837a5fc0627ac32f67615f09c89a4baefc9c6a50edaf24	2021-08-06 18:16:23+00
515	5273514	0x532bf79120d055ca4b40458ef50e0085046ecad19939f7671a493c24eca51d51	2021-08-06 18:16:38+00
516	5273515	0x54687cdef584434d2fc851910815f3cdc5f8b2c614a7c3a476a8304ffbd0d079	2021-08-06 18:16:53+00
517	5273516	0xee7d4259ef7b03b8de6daff36074ce14b5994db0118cdfa70aeafb099cbf87c9	2021-08-06 18:17:08+00
518	5273517	0xb2adf7d18af3fcdf342964702024b38e67b5661e498fd934c49dbe3c1b9cb1a2	2021-08-06 18:17:23+00
519	5273518	0x7e7c22b7ff784e76b801f7f5025e5da34a3e67b2da4cf14504dc4eb771e4530a	2021-08-06 18:17:38+00
520	5273519	0x9b1766c743d1f49119e6398d28806f49d0c1f481225d62818b03a6e016cb2c86	2021-08-06 18:17:53+00
\.


--
-- Data for Name: enhanced_transaction; Type: TABLE DATA; Schema: vulcan2x; Owner: user
--

COPY vulcan2x.enhanced_transaction (hash, method_name, arg0, arg1, arg2, args) FROM stdin;
\.


--
-- Data for Name: job; Type: TABLE DATA; Schema: vulcan2x; Owner: user
--

COPY vulcan2x.job (id, name, last_block_id, status, extra_info) FROM stdin;
8	Polling_Transformer	200	processing	\N
9	MKR_Transformer	240	processing	\N
10	MKR_BalanceTransformer	240	processing	\N
3	raw_log_0x105bf37e7d81917b6feacd6171335b4838e53d5e_extractor	320	processing	\N
4	raw_log_0x023a960cb9be7ede35b433256f4afe9013334b55_extractor	320	processing	\N
11	ESMTransformer	320	processing	\N
5	raw_log_0x33ed584fc655b08b2bca45e1c5b5f07c98053bc1_extractor	360	processing	\N
12	ESMV2Transformer	320	processing	\N
13	DsChiefTransformer_v1.2	360	processing	\N
14	ChiefBalanceTransformer_v1.2	360	processing	\N
6	raw_log_0x1a7c1ee5ee2a3b67778ff1ea8c719a3fa1b02b6f_extractor	400	processing	\N
7	raw_log_0xe2d249ae3c156b132c40d07bd4d34e73c1712947_extractor	440	processing	\N
15	Vote_proxy_factory_transformer_v1.2	400	processing	\N
16	Vote_delegate_factory_transformer	440	processing	\N
1	raw_log_0xdbe5d00b2d8c13a77fb03ee50c87317dbc1b15fb_extractor	480	processing	\N
2	raw_log_0xc5e4eab513a7cd12b2335e8a0d57273e13d499f7_extractor	480	processing	\N
\.


--
-- Data for Name: transaction; Type: TABLE DATA; Schema: vulcan2x; Owner: user
--

COPY vulcan2x.transaction (id, hash, to_address, from_address, block_id, nonce, value, gas_limit, gas_price, data) FROM stdin;
1	0x84d5489492368f23a109fa94a75e1b7785ab24e9fa7acb2a4652bf089c591a78	0xc5e4eab513a7cd12b2335e8a0d57273e13d499f7	0xdb33dfd3d61308c33c63209845dad3e6bfb2c674	89	5125	0	7000000	5000000000	0x40c10f19000000000000000000000000db33dfd3d61308c33c63209845dad3e6bfb2c67400000000000000000000000000000000000000000000d3c21bcecceda1000000
2	0x9fa380e102353b6f891b19bcbf74f03d644d5a7ecf9a406ca6dac71e73755e7a	0xc5e4eab513a7cd12b2335e8a0d57273e13d499f7	0xdb33dfd3d61308c33c63209845dad3e6bfb2c674	91	5127	0	7000000	5000000000	0x7a9e5e4b000000000000000000000000b9b861e8f9b29322815260b6883bbe1dbc91da8a
3	0x5f6eb85915fe849fdc9df29df900433ebec92f833e3391b207a4df33314427de	0x0000000000000000000000000000000000000000	0xdb33dfd3d61308c33c63209845dad3e6bfb2c674	62	5111	0	7000000	5000000000	0x60806040526012600655600060075534801561001a57600080fd5b5060405161217c38038061217c8339818101604052602081101561003d57600080fd5b810190808051906020019092919050505033600160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055503373ffffffffffffffffffffffffffffffffffffffff167fce241d7ca1f669fee44b6fc00b8eba2df3bb514eed0f6f668f8f89096e81ed9460405160405180910390a28060058190555050612093806100e96000396000f3fe608060405234801561001057600080fd5b50600436106101735760003560e01c80637a9e5e4b116100de578063b753a98c11610097578063bf7e214f11610071578063bf7e214f14610684578063daea85c5146106ce578063dd62ed3e1461072a578063f2d5d56b146107a257610173565b8063b753a98c146105be578063bb35783b1461060c578063be9a65551461067a57610173565b80637a9e5e4b146104305780638da5cb5b1461047457806395d89b41146104be5780639dc29fac146104dc578063a0712d681461052a578063a9059cbb1461055857610173565b8063313ce56711610130578063313ce567146102ee57806340c10f191461030c57806342966c681461035a5780635ac801fe1461038857806370a08231146103b657806375f12b211461040e57610173565b806306fdde031461017857806307da68f514610196578063095ea7b3146101a057806313af40351461020657806318160ddd1461024a57806323b872dd14610268575b600080fd5b6101806107f0565b6040518082815260200191505060405180910390f35b61019e6107f6565b005b6101ec600480360360408110156101b657600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190803590602001909291905050506108de565b604051808215151515815260200191505060405180910390f35b6102486004803603602081101561021c57600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050610a53565b005b610252610b9c565b6040518082815260200191505060405180910390f35b6102d46004803603606081101561027e57600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190803573ffffffffffffffffffffffffffffffffffffffff16906020019092919080359060200190929190505050610ba2565b604051808215151515815260200191505060405180910390f35b6102f661113a565b6040518082815260200191505060405180910390f35b6103586004803603604081101561032257600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff16906020019092919080359060200190929190505050611140565b005b6103866004803603602081101561037057600080fd5b8101908080359060200190929190505050611353565b005b6103b46004803603602081101561039e57600080fd5b8101908080359060200190929190505050611360565b005b6103f8600480360360208110156103cc57600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff16906020019092919050505061140a565b6040518082815260200191505060405180910390f35b610416611422565b604051808215151515815260200191505060405180910390f35b6104726004803603602081101561044657600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050611435565b005b61047c61157c565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b6104c66115a2565b6040518082815260200191505060405180910390f35b610528600480360360408110156104f257600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190803590602001909291905050506115a8565b005b6105566004803603602081101561054057600080fd5b8101908080359060200190929190505050611b46565b005b6105a46004803603604081101561056e57600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff16906020019092919080359060200190929190505050611b53565b604051808215151515815260200191505060405180910390f35b61060a600480360360408110156105d457600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff16906020019092919080359060200190929190505050611b68565b005b6106786004803603606081101561062257600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190803573ffffffffffffffffffffffffffffffffffffffff16906020019092919080359060200190929190505050611b78565b005b610682611b89565b005b61068c611c72565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b610710600480360360208110156106e457600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050611c97565b604051808215151515815260200191505060405180910390f35b61078c6004803603604081101561074057600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050611cca565b6040518082815260200191505060405180910390f35b6107ee600480360360408110156107b857600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff16906020019092919080359060200190929190505050611cef565b005b60075481565b610824336000357fffffffff0000000000000000000000000000000000000000000000000000000016611cff565b610896576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f64732d617574682d756e617574686f72697a656400000000000000000000000081525060200191505060405180910390fd5b60018060146101000a81548160ff0219169083151502179055507fbedf0f4abfe86d4ffad593d9607fe70e83ea706033d44d24b3b6283cf3fc4f6b60405160405180910390a1565b6000600160149054906101000a900460ff1615610963576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260128152602001807f64732d73746f702d69732d73746f70706564000000000000000000000000000081525060200191505060405180910390fd5b81600460003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020819055508273ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff167f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b925846040518082815260200191505060405180910390a36001905092915050565b610a81336000357fffffffff0000000000000000000000000000000000000000000000000000000016611cff565b610af3576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f64732d617574682d756e617574686f72697a656400000000000000000000000081525060200191505060405180910390fd5b80600160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550600160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff167fce241d7ca1f669fee44b6fc00b8eba2df3bb514eed0f6f668f8f89096e81ed9460405160405180910390a250565b60025481565b6000600160149054906101000a900460ff1615610c27576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260128152602001807f64732d73746f702d69732d73746f70706564000000000000000000000000000081525060200191505060405180910390fd5b3373ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff1614158015610cff57507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff600460008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205414155b15610efd5781600460008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020541015610df6576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601e8152602001807f64732d746f6b656e2d696e73756666696369656e742d617070726f76616c000081525060200191505060405180910390fd5b610e7c600460008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205483611f58565b600460008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020819055505b81600360008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020541015610fb2576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601d8152602001807f64732d746f6b656e2d696e73756666696369656e742d62616c616e636500000081525060200191505060405180910390fd5b610ffb600360008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205483611f58565b600360008673ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002081905550611087600360008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205483611fdb565b600360008573ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020819055508273ffffffffffffffffffffffffffffffffffffffff168473ffffffffffffffffffffffffffffffffffffffff167fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef846040518082815260200191505060405180910390a3600190509392505050565b60065481565b61116e336000357fffffffff0000000000000000000000000000000000000000000000000000000016611cff565b6111e0576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f64732d617574682d756e617574686f72697a656400000000000000000000000081525060200191505060405180910390fd5b600160149054906101000a900460ff1615611263576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260128152602001807f64732d73746f702d69732d73746f70706564000000000000000000000000000081525060200191505060405180910390fd5b6112ac600360008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205482611fdb565b600360008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020819055506112fb60025482611fdb565b6002819055508173ffffffffffffffffffffffffffffffffffffffff167f0f6798a560793a54c3bcfe86a93cde1e73087d944c0ea20544137d4121396885826040518082815260200191505060405180910390a25050565b61135d33826115a8565b50565b61138e336000357fffffffff0000000000000000000000000000000000000000000000000000000016611cff565b611400576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f64732d617574682d756e617574686f72697a656400000000000000000000000081525060200191505060405180910390fd5b8060078190555050565b60036020528060005260406000206000915090505481565b600160149054906101000a900460ff1681565b611463336000357fffffffff0000000000000000000000000000000000000000000000000000000016611cff565b6114d5576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f64732d617574682d756e617574686f72697a656400000000000000000000000081525060200191505060405180910390fd5b806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff167f1abebea81bfa2637f28358c371278fb15ede7ea8dd28d2e03b112ff6d936ada460405160405180910390a250565b600160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b60055481565b6115d6336000357fffffffff0000000000000000000000000000000000000000000000000000000016611cff565b611648576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f64732d617574682d756e617574686f72697a656400000000000000000000000081525060200191505060405180910390fd5b600160149054906101000a900460ff16156116cb576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260128152602001807f64732d73746f702d69732d73746f70706564000000000000000000000000000081525060200191505060405180910390fd5b3373ffffffffffffffffffffffffffffffffffffffff168273ffffffffffffffffffffffffffffffffffffffff16141580156117a357507fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff600460008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205414155b156119a15780600460008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002054101561189a576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601e8152602001807f64732d746f6b656e2d696e73756666696369656e742d617070726f76616c000081525060200191505060405180910390fd5b611920600460008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205482611f58565b600460008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002060003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020819055505b80600360008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020541015611a56576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601d8152602001807f64732d746f6b656e2d696e73756666696369656e742d62616c616e636500000081525060200191505060405180910390fd5b611a9f600360008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000205482611f58565b600360008473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002081905550611aee60025482611f58565b6002819055508173ffffffffffffffffffffffffffffffffffffffff167fcc16f5dbb4873280815c1ee09dbd06736cffcc184412cf7a71a0fdb75d397ca5826040518082815260200191505060405180910390a25050565b611b503382611140565b50565b6000611b60338484610ba2565b905092915050565b611b73338383610ba2565b505050565b611b83838383610ba2565b50505050565b611bb7336000357fffffffff0000000000000000000000000000000000000000000000000000000016611cff565b611c29576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f64732d617574682d756e617574686f72697a656400000000000000000000000081525060200191505060405180910390fd5b6000600160146101000a81548160ff0219169083151502179055507f1b55ba3aa851a46be3b365aee5b5c140edd620d578922f3e8466d2cbd96f954b60405160405180910390a1565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000611cc3827fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6108de565b9050919050565b6004602052816000526040600020602052806000526040600020600091509150505481565b611cfa823383610ba2565b505050565b60003073ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff161415611d3e5760019050611f52565b600160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168373ffffffffffffffffffffffffffffffffffffffff161415611d9d5760019050611f52565b600073ffffffffffffffffffffffffffffffffffffffff166000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff161415611dfc5760009050611f52565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663b70096138430856040518463ffffffff1660e01b8152600401808473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020018373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001827bffffffffffffffffffffffffffffffffffffffffffffffffffffffff19167bffffffffffffffffffffffffffffffffffffffffffffffffffffffff19168152602001935050505060206040518083038186803b158015611f1457600080fd5b505afa158015611f28573d6000803e3d6000fd5b505050506040513d6020811015611f3e57600080fd5b810190808051906020019092919050505090505b92915050565b6000828284039150811115611fd5576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260158152602001807f64732d6d6174682d7375622d756e646572666c6f77000000000000000000000081525060200191505060405180910390fd5b92915050565b6000828284019150811015612058576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f64732d6d6174682d6164642d6f766572666c6f7700000000000000000000000081525060200191505060405180910390fd5b9291505056fea265627a7a72315820f0a305fe5621a6e2fefbc80c6a936a1c9f826889cce9d60e146ff85d5f49451964736f6c634300050c00324d4b520000000000000000000000000000000000000000000000000000000000
\.


--
-- Data for Name: address; Type: TABLE DATA; Schema: vulcan2xarbitrum; Owner: user
--

COPY vulcan2xarbitrum.address (address, bytecode_hash, is_contract) FROM stdin;
\.


--
-- Data for Name: block; Type: TABLE DATA; Schema: vulcan2xarbitrum; Owner: user
--

COPY vulcan2xarbitrum.block (id, number, hash, "timestamp") FROM stdin;
1	154800	0xdc0466d254af41a4bcfebb27828bc35f807131ec43a001105594c5e1da8e6330	2022-08-23 20:29:18+00
2	154801	0xe9fbcfa944b6f4adfd7b8416ed87775a55bdbaeb9f419cc8207f85ef4a75954c	2022-08-23 20:29:21+00
3	154802	0xca275de4de3bcbb2128d811ad66cb48e23d457ed6da4f647d92a654388f3ed95	2022-08-23 20:29:21+00
4	154803	0xad92eee8813ef3094ebf12aee532a915970d579246d4899e92909ddaa8248f0d	2022-08-23 20:29:22+00
5	154804	0x71cd90dc1d140ba1156eeeb6e9e04c9b7a965653ee832b62a0237837185269b0	2022-08-23 20:30:40+00
6	154805	0x1e3b6af47b24cd5fe79a52694845e5832a17d3a37db80e151ab29a06ed8c6d1e	2022-08-23 20:30:41+00
7	154806	0xf4ebe8aa49ee3af2225ded2cbc6d29f68097d9018089ec0dc7135ba059681a09	2022-08-23 20:31:28+00
8	154807	0xe9c510b08fa47d5c293fbb15b7c4b5998bf042c8e249aa1d324120138f77c3dd	2022-08-23 20:32:20+00
9	154808	0x26bedd7fd35ef8194819b3fe5ed95ff5fb85af2d31426df3137ed7897eb82e8c	2022-08-23 20:32:32+00
10	154809	0xa52177fdcd711059c9003f3063609a74f87ec0b4644ad1894b2ef0e34958b79b	2022-08-23 20:33:05+00
11	154810	0x90cb53bf0989e2d15cfbea89e5384988bc30f8896869344a3fb8b0d681eaa220	2022-08-23 20:33:33+00
12	154811	0x1737fd88c7d9bbc352dba440c27d42a745b1ec0a009cd2b29b4591905bd6b91f	2022-08-23 20:33:34+00
13	154812	0x5c5d2571ebc20ef4c05f8f16b0ff8b8183c31a9c2b0e49d6cacad37dc5f6e831	2022-08-23 20:34:41+00
14	154813	0xdb3f47ab22d5afc46bf0abffa45675fcda9c2983fac9ba326aff3a75c85d815c	2022-08-23 20:35:40+00
15	154814	0xc3ce5e79d5037ddcba95e423a961d23b1db6101fa7e0471359ba25a9b77a8752	2022-08-23 20:35:42+00
16	154815	0xe5334692a9cdfc52dd3dcdb52e051939566a65b6205c6b1b0d51c6a3acdc6e65	2022-08-23 20:35:45+00
17	154816	0x872dbcd84840b09192b62633af4bd465ef643230bb9ac34e0e042f2d87eea74e	2022-08-23 20:35:45+00
18	154817	0xff3a05813b5f7332522cf99674faacc83d22b87d1a50c432af2bcc135fd715bf	2022-08-23 20:37:46+00
19	154818	0xae63e9466d0725bcf5a62214c77b83ff9a2b3c90ce584d50cb3b9f582d2a71ec	2022-08-23 20:38:55+00
20	154819	0x749c9d788cef14b22198990c8b1d6ec11893000ede12f0087a2ef37f1daaaa7b	2022-08-23 20:39:52+00
21	154820	0xae9da68a6e891263924d5a88b8f22d80ef5bb98c5b70ad4ae27a389c1a9637ad	2022-08-23 20:40:31+00
22	154821	0x005d9962109a97f9cd80011cefa09f198a19f9c491fa4ff0ef9f89e9e88cdcdb	2022-08-23 20:41:58+00
23	154822	0xc84caf99b394b922e801ca09096d2f13fb36280dd3cf29644e09f1195d8d7ad5	2022-08-23 20:42:14+00
24	154823	0x496848a80f2741a1656157f12aec66c0d8c07d459e89577bd34d81143d45a041	2022-08-23 20:44:04+00
25	154824	0x14c67c3e279fd390e41c82c6ad6ab9648687f022f7039da89961f1b7d9b23919	2022-08-23 20:44:04+00
26	154825	0x1d90707fb93717968db7ca351dd1f38099a79da0f94b32a337ec6deb8d5a971d	2022-08-23 20:46:10+00
27	154826	0x46c3e0b663828cf769574a06d650671038232cd72bfbafbc0b4cfc40d9db4316	2022-08-23 20:46:10+00
28	154827	0xb5235519eeed3f0497ebf7a2a46abf015929373995179281cc91c3d9e4b80a5d	2022-08-23 20:46:19+00
29	154828	0x313ffe4da62c7d5056fef6d2d958fc43a3a864dc226e17c37ea3347c131c9e31	2022-08-23 20:46:49+00
30	154829	0xba266ec5968b4c6764e03f306c7032918f1e7208cd99d6553bdbacfb726c7347	2022-08-23 20:48:16+00
31	154830	0x8b4d767795450dfe4acf25c450397611aeb4ad0064c6d634c47eedf80d3152ad	2022-08-23 20:49:00+00
32	154831	0x36eb9e6f564cff4a63a785e9869d83d91f54ca06c4b5ddbb561361df0c28fb01	2022-08-23 20:49:00+00
33	154832	0x27b9d4c823fc2603142f44758978d80d68742c10e99a2d6256dfffe7f2a9fafc	2022-08-23 20:50:07+00
34	154833	0x0ae7c33c43042fed24da9d095733e0f0c175897b3b981f7ba1a5e37ff29ff7a7	2022-08-23 20:50:10+00
35	154834	0x4aabb033dec3c82cebabb039069b3b241d22174472e0799ae2674364430708ac	2022-08-23 20:50:22+00
36	154835	0x406502155d366f3d00949ced8ece9a3cf8cb30e47abc226259cc3ea7b239f335	2022-08-23 20:52:28+00
37	154836	0xa1995063f0e05816cc9e30cf507ca9d8a583b3d58e83ffadce3568ddb1f6ccb8	2022-08-23 20:52:49+00
38	154837	0x34a8f2d03d9a97641327564276a27ca12017701f65de82fdfc1b5a11c242bac4	2022-08-23 20:53:19+00
39	154838	0x801ae49d4ec0e7a17e316a8a33e41f2669a50c6dde2bea480877083c732a28c9	2022-08-23 20:54:34+00
40	154839	0x871f40d080bc0058e6f0a35d4fc675d17b33bf08fb47482be823577fd8e5bae9	2022-08-23 20:56:40+00
41	154840	0xb1f22738870dbf004fad3868f96f271a5124dd614e39c7917c9849521c851d80	2022-08-23 20:56:40+00
42	154841	0x9a3630cd57e80f3593a8c4b9334ab9e75db6982852fff4afc7b2c1f41b15a7c2	2022-08-23 20:58:45+00
43	154842	0xd8a964b7e9df496b98371b7c9452b4cb9dffe756fc5902153437681c05d21537	2022-08-23 21:00:51+00
44	154843	0xed2a082de78dece8ac2f1014652b22fce6b27f7f72a20ca6530dd0203f4bdfd7	2022-08-23 21:00:51+00
45	154844	0x4c539f82e6063582215eaf97616d0e8449d1590d6ace406427b1b05414fe0c71	2022-08-23 21:01:54+00
46	154845	0xc686262db1f8492b5faa63a2af60ebda820e4d6aff5072dc7f2aade498ca9e13	2022-08-23 21:02:04+00
47	154846	0x1df3d6ad6db16abb1197d0021adc4674aa9f279f39f6ddd67061e970b6388241	2022-08-23 21:02:18+00
48	154847	0x809a59a92e7f3fdcf3dddfd6eac09fc69203045f6e857fed915c5d564d674d4d	2022-08-23 21:02:57+00
49	154848	0xe5198a746384942fd210f7c71d178c70453ef574d6f9788a850f4fbe12136ff2	2022-08-23 21:03:51+00
50	154849	0x00c6e1ec4d6a5d5203712474423ac18376d317d66c511bdde5b0af0da24e4420	2022-08-23 21:05:03+00
51	154850	0x7df926b51e9996b23da57378cc6e622d14503bd60642faff44ec508ce8df4bbb	2022-08-23 21:05:34+00
52	154851	0xa0d8fa6c9feeb2124a1f0da9ba4e3abf4e3ab26eec916208cbc094031c9c2dd8	2022-08-23 21:06:37+00
53	154852	0xec1bd7c230c1f34ccb92ffd6ef17e193b97045f5e0a10dc25277806e1ca203e6	2022-08-23 21:06:49+00
54	154853	0x29029093dca63efc74cef4748c083662738dfb3994d6f71a8be37b7220755004	2022-08-23 21:07:04+00
55	154854	0x1c45f4f09d6e79b7f8712ae8f7f6f5eec33673b2259dd810c2334c145c979376	2022-08-23 21:07:09+00
56	154855	0x10761f340b3519d5589b73f0b274bfcec7d7b9a23e832c68ce1e4b559b4499ba	2022-08-23 21:07:13+00
57	154856	0x2085f83a62842f245b1fe4bcbd87c989c2a35de89fb7d5177e67e076d9ef3177	2022-08-23 21:07:18+00
58	154857	0x9f895a23278abbb283739acd5d650e9899a85136a72a4e8a4f1c63a9a21adc07	2022-08-23 21:07:29+00
59	154858	0xb4ac9e3f4ca1e96c0e8366c5cea34524de0cb0014863571f9f3ba496192acd95	2022-08-23 21:07:47+00
60	154859	0xcf6c3ee22fd5ae9574be2e4657283730584732e705f84b92aeafe04d65de4be7	2022-08-23 21:07:58+00
61	154860	0x3d6b23be3360db5e831a37b91226e881c553c77cd2d2dcc6cc56ad816b5764f3	2022-08-23 21:08:08+00
62	154861	0xbbf9d8b33afc0d5464864e6666ffbcc3443bff04ed81b10230fd7d54c9b721a6	2022-08-23 21:08:20+00
63	154862	0xede6a4981a93d1ffcf036cdceb31673276edc27a3edec9d1df395a1d8025b986	2022-08-23 21:08:32+00
64	154863	0x59ed933dbecc9a911dd16a3a5db805d746d581bdf4d8920716252528afb56bfa	2022-08-23 21:08:44+00
65	154864	0x77b67cc158cc631a0d4bf04d79460f3ee90bf7044a78b460bd3b981d09bb9ee0	2022-08-23 21:08:53+00
66	154865	0x578a72de2ae6337148ce5e0460d724ccd1acf8201c9deb2ea8d0ffa3179db3f6	2022-08-23 21:09:05+00
67	154866	0xec539975703b75d7c6a6654d5f368958ef17b345db062f6821d398ce8bfa0701	2022-08-23 21:09:15+00
68	154867	0xd4b405116c9301079f1e3a51701c1e6bc05f09dc3002611d64ec1fdd8160bcba	2022-08-23 21:09:17+00
69	154868	0x6942d79df671792c27913c8899bb419d5a814e7601c1ec16814e9e7e00d4f287	2022-08-23 21:09:31+00
70	154869	0xac9d04a30fa71e6b2be58be9d04d47932af6264ec3c783a73d29d56a4e99e9a2	2022-08-23 21:09:43+00
71	154870	0xed9ac7312dad67c35379e537ba3a9d4233df0eb3b472ed3d969582c7d0e8116e	2022-08-23 21:09:53+00
72	154871	0x553184a032fea63be84f5fc8d7d6136a4be7b92429c977e2fa3d4c4649daeda4	2022-08-23 21:10:05+00
73	154872	0xbdeff29f9af4800ddfc0fb308748ecbaac7e60df52d709cf7518c1452c4f68e6	2022-08-23 21:10:17+00
74	154873	0xa93d157ae3c6acc7d534cca182949fd737a04cf2d18263454e02e82d7f58c821	2022-08-23 21:10:31+00
75	154874	0x006100296103c3795c49650db60870ab3a3745fc262a997fdde8760f8cf75ec0	2022-08-23 21:10:42+00
76	154875	0x10809b0dd2e33aaaa523f19fae1ca05b4587413733d61f1cbac4f92eaf29f638	2022-08-23 21:10:54+00
77	154876	0xeeb3e7f705689a211ab28b6aef3a94cafc06728c8ce3495bf49e5e914d01f78c	2022-08-23 21:11:08+00
78	154877	0xc964254358812a33e0c382d260daa55b552f621551bb4ced331bad1e15453048	2022-08-23 21:11:18+00
79	154878	0xde5b2a4c132d11341e0571c0df64d5bb67201c146e9b42841b8ce2a78b87cd83	2022-08-23 21:11:21+00
80	154879	0x15d4c845e75e5a15a97325d067a0da95419c98f264adcba0487ba49f264a36d2	2022-08-23 21:11:32+00
81	154880	0x5f451781ecfbd612205879d352d354485414c34b52a6e7eabda3462d24d91410	2022-08-23 21:11:49+00
82	154881	0xe8a84a934f2c4f904d3997951546fd842fd75fd586a4721ece5bf4200d858ca2	2022-08-23 21:11:59+00
83	154882	0xb52e021a4395a96b8a1a6440a8506fded907dbbcc685404064caf1f2605d51b0	2022-08-23 21:12:17+00
84	154883	0xc9fbe9acd196a0f0718de529d92d559686a985c7bfd3c3518e72fc23f5228ca9	2022-08-23 21:12:29+00
85	154884	0xd8d817f57d8269d614ab6e0a1cbb5dfa84ad5944f40321a10d42b7b3198d5786	2022-08-23 21:12:40+00
86	154885	0x26d95b7da469bfee93fde8ed5082e1c37d0340f42ea7068375696eba3f68083f	2022-08-23 21:12:53+00
87	154886	0x65ae0d369b890e7bf7beaf16219fbdcdc503d75394faa1b517b535715b2ecaab	2022-08-23 21:13:06+00
88	154887	0x66fdb56056e4c0fd149f8ed28071bb145cc97e4d61276b302beb2908a881dfa4	2022-08-23 21:13:18+00
89	154888	0x25c0aa3aff87d0f0dc06208184de506454d0073f0dbea2696ae31fde545d0017	2022-08-23 21:13:27+00
90	154889	0xd4c75f8e1d1f8875cfa000f648a8b9242df14a49938a94825738649379537217	2022-08-23 21:13:30+00
91	154890	0x0168c1a3ffd12e8bc174e68a6e30d7677011db02bd4cb1e9366099b2b02ecccb	2022-08-23 21:13:42+00
92	154891	0xb1906d991c62706f62645fe7bde32bd97f890cd066e2ebfd0563bf77c31bc8b1	2022-08-23 21:13:54+00
93	154892	0x50ac982052a7b80f895b8521e28ad8c53bf2eff6ea7dafbcb8ede0f3090d2e4e	2022-08-23 21:14:04+00
94	154893	0xa4a45b74c5425066d9165a95e77b864f9126cf531913a0a99a720cb43473c781	2022-08-23 21:14:15+00
95	154894	0x3fd2b06ca97edd101e346e0dc811be1dc4e0b04a69707872bbe59f5fdf8be5a1	2022-08-23 21:14:32+00
96	154895	0xf139009dcdc829c78a793dbf495b13a6815f35d4cf9d5668dc8e70f8dc5c39be	2022-08-23 21:14:43+00
97	154896	0x2bbc1dd773162947dc7bcdb593bb8794410893de31d767feed965c686296b8e2	2022-08-23 21:15:03+00
98	154897	0x6e998a8ece1fef28e4eac60a5ede7206cc9f59d62bef0353d92b65f2c3ccb9d2	2022-08-23 21:15:17+00
99	154898	0xeabeea7d7a58d39a7a07c10d525f9f0dc910c40ad43b1cfc1231b47d91d27e8b	2022-08-23 21:15:28+00
100	154899	0x4d3da19d8757bda533e1f96f676791ba8bcbb1dd08a032c1c2727c6867a680a0	2022-08-23 21:15:33+00
101	154900	0x3a22129eabafa5544a29356bb83a4aad090c40409eba0657139de46d8e3dc871	2022-08-23 21:15:42+00
102	154901	0xafe292bc35029e89b9cc737f3657295c82d4f8d88e66c52b4b97ef8b4ea3bc15	2022-08-23 21:15:58+00
103	154902	0x587b2d40e0abc4f891a0d9fb5ee38e2e6d7a4944ee4901bd0184340a519fc720	2022-08-23 21:16:09+00
104	154903	0x572f637c76777f723fbb16475d8cc35aaa7d1cac33a9e79bd1817adc5c90236d	2022-08-23 21:16:21+00
105	154904	0xbbedaee7c9f8e6c0e095726787f31eae5e651271595d2a1fdb012b177e206c5d	2022-08-23 21:16:36+00
106	154905	0x03ac7b1cdbafc3b6b6d31a36f1365f0961548585059bdaec05f36e114d6fc3a4	2022-08-23 21:16:53+00
107	154906	0x01ef2bdf32d02b69bee6e6fec716c7d4f624f9dcddf3401703c77eb985b86e4b	2022-08-23 21:17:01+00
108	154907	0x972f2ee725d9168770828076f6580687c841972557a8628359b2368275f0f768	2022-08-23 21:17:05+00
109	154908	0x502dd30401827960208bfe9e3cfe90275fcc5bb0d099c1e3a1050a355c5ec0cc	2022-08-23 21:17:16+00
110	154909	0x64bf626eb5439b30df0632549869ec0a28aa817590c71c24dc7120c4e50b1aa3	2022-08-23 21:17:28+00
111	154910	0x292e0b1bda4d5676b2ee2023fce398e2ebfefc28aa8568beeb4327d724b18177	2022-08-23 21:17:39+00
112	154911	0x16789d694f1413b603c5e7f84d137adb87fd1d2339a8c1eeea3d1c4283bce213	2022-08-23 21:17:39+00
113	154912	0x67e0933ad1fc99d1b6c8bb8eb1cbeda5a5a8e02d781a7edfc36805181a7c0a55	2022-08-23 21:17:51+00
114	154913	0xf350d64358eab303b7df9f03e0a5421441c879bb96939246d0f87e5f54c50175	2022-08-23 21:18:05+00
115	154914	0x1913121fa62e996d9de731c5e114367d56e90527a0dd6a298a76ca713e7b4aad	2022-08-23 21:18:17+00
116	154915	0xac875a3daab9f7ffe6af2a3da4791a87dce8c9f0242da863236da0ddb60d3f36	2022-08-23 21:18:31+00
117	154916	0x5ce45af29fd1cc2a30bc0cbbc49de4da9bdd9e757fbc2ce196b61e5869cd7be2	2022-08-23 21:18:43+00
118	154917	0x2607737c5ec0d110371f1d0bff43e748ef46500764ef931ace2f01c507ded690	2022-08-23 21:18:54+00
119	154918	0xce8804ad361af0bc3e63e2c903a15e976d1ef8b80a173ae8701b089332d8bb1b	2022-08-23 21:19:13+00
120	154919	0x162ad533bb6a43d0cbc00a68f433bb087aec41ba429cfdfb95b644422acab43b	2022-08-23 21:19:26+00
121	154920	0xcf71bcc0b906b2dd4312803d56b3ce184ea84a8d02ed408ca5f650a061328d5d	2022-08-23 21:19:42+00
122	154921	0x3415b5aef61401f6b3a35acbffa5ea40151d82cd11b1ed90f4d491778d1690d5	2022-08-23 21:19:45+00
123	154922	0x7ada71b0c4bc9d0a3b92abcf97ef13fb915137edfa77d7b8282f80a640cf7ce5	2022-08-23 21:19:59+00
124	154923	0x1c00446f04c280a10f6c954184cb433a055aa3d024210da692f4d2af12c54699	2022-08-23 21:20:27+00
125	154924	0xd6f63a75e83137cc6f57a6ac967dfb0d000e16bf25a59c689070db11b1a50661	2022-08-23 21:20:28+00
126	154925	0xe99ae248774fb80cec519a02bfca07b0d4fe3de028ab7fa8b27e1ef4923a07f0	2022-08-23 21:20:41+00
127	154926	0xacd2609c361d3a00a8272b907c769767eacbf68977de76853d6b656c1a0a9ff5	2022-08-23 21:20:57+00
128	154927	0x4a04be9eb32d1e850698b020853246a5f2cfb308a45cf0725d4886b6091dbd1c	2022-08-23 21:21:08+00
129	154928	0x0139c8823c63cc4d3e99cfe11bddd166da5a87e32db0e8569a6b6b07c6184719	2022-08-23 21:21:20+00
130	154929	0xcd7e7d69eca58089236c1f450be9eacedd8d4a64a0262e7eeefc977e14f8b04b	2022-08-23 21:21:31+00
131	154930	0x1f2117435178060c4f3ec33e6477ecd6aa709119246f709fa77e060f664ff209	2022-08-23 21:21:42+00
132	154931	0x749cd43fb39077d1db9520d96ef400e179c582f85e07c0192a93e97a2fee0941	2022-08-23 21:21:51+00
133	154932	0xa8ae872a4780668a8509bbdfd3c175abc4338b30d197a92724908a12706c1409	2022-08-23 21:21:53+00
134	154933	0x6653c98057fafa2f0d1b23a6192864d4e5c3c866b6078f15388a7c1419853a7c	2022-08-23 21:22:04+00
135	154934	0x9d1bb630258d9e90d459f8ffee470ca3162c0ebd3d873eddcef6742638cd4af7	2022-08-23 21:22:19+00
136	154935	0xa4b697064db54a23016299996830698696e15ba690b67994875613e0853b9914	2022-08-23 21:22:30+00
137	154936	0x57179db8a563c8b35ab007e20870d602c1ee8212bedae369f0e38f784e58ad15	2022-08-23 21:22:45+00
138	154937	0x81b6e8481cfdb841fcb6ae7987bbf44a0e7187c878e43633326229cbbeafa47c	2022-08-23 21:22:55+00
139	154938	0x1a2a624f22fbbcf4d6fe5843c2c6ff36a3fadb5af2809fad299bea267a4f78e6	2022-08-23 21:22:56+00
140	154939	0x0d3590414e969b8966e7af793d8c7a76146624f9d533a015b6f33ce1ec1ea44e	2022-08-23 21:23:13+00
141	154940	0x5ec69b72da85d882b695a5ef8d942c8c82da67fb4af1efc83881c6b339d2d4cb	2022-08-23 21:23:23+00
142	154941	0x3ac80e9e99316914d96c35a26535c880bb0e9985f598758611c683ee1270e421	2022-08-23 21:23:34+00
143	154942	0x23f9e5cf5887132ab6279a7a2d0249c62aa0fb21175ddd4886b9989f06fadcce	2022-08-23 21:23:52+00
144	154943	0x53360ff9dabf07c2b53a2c885a376b6a6888f7844d4288c1159c008d00ea7324	2022-08-23 21:23:57+00
145	154944	0x60eb4904bbbcb545a0da8385b6141cd860a2e8a693b8c14850880899691404fe	2022-08-23 21:24:02+00
146	154945	0x441d179b95bd6cd7c373a7ae133989434b0195e23bf2e9df3c59550379a42ffe	2022-08-23 21:24:11+00
147	154946	0x28edc398750e0c277791918887c943e73ee883ef142b50e8a250c3bf96d713b3	2022-08-23 21:24:21+00
148	154947	0x9b4c4e5c8c2342b80c365acb403d9d86d2344fdac5567d55f251c2ab828e37dd	2022-08-23 21:24:33+00
149	154948	0xfd1f641a5c3874ddf2145a058780315a0fbbece89620fe6c38e0850e6ca503aa	2022-08-23 21:24:44+00
150	154949	0xe10f3b9d1d9449b8f33ea17f392783b52e4ef06795015496988951a0c93206a0	2022-08-23 21:24:57+00
151	154950	0x33334be73226ed12e9d52a631499ac088195541324d2df498e1e8490a7025f79	2022-08-23 21:25:07+00
152	154951	0x43efbff9717c039e04ea6a0a4c2e8fd8dde931cd765c184701af194ca8a7ae9e	2022-08-23 21:25:21+00
153	154952	0xdffc439581cdf7aac3f66cdcdcd6fc52e737bd7216e8755ec404ba0f467a342b	2022-08-23 21:25:28+00
154	154953	0x29513689f0ccbd9afcd884c75f6b8ca5fd26f7a4747c4f84dababe9636231b8e	2022-08-23 21:25:43+00
155	154954	0xdc4818422a94838edf9ca59ecb1b8aac3f6d92ecb8c0aac53ca13e6af57916fd	2022-08-23 21:25:55+00
156	154955	0xf53ac10622df15c09ee00c3c9e97591c1c9e9fbb44463a887da1be915bf894bb	2022-08-23 21:26:03+00
157	154956	0xe536b1c1ffaf0e4f85e3cfe6a8eabf9af6d33fc10c3af30a4736959521ba350a	2022-08-23 21:26:04+00
158	154957	0xd14b0d13d82fbab7e49df2ca428d7688223a742c35f1ddab51affdc84cb692de	2022-08-23 21:26:15+00
159	154958	0x9d71871eb97b1051d5d13a40b895f0ebabf00cff2661f9b5db90165c1ed7e956	2022-08-23 21:26:27+00
160	154959	0x22d49df12c64379fecb7a6263068327e1e82f5abf49f76c3f1ef86a5569b50fe	2022-08-23 21:26:27+00
161	154960	0x5b26325d598eaa580e051cbbd2c592f6b204b6463fca47fc9e24f7d48dabbb34	2022-08-23 21:26:45+00
162	154961	0x87b724545e9bffed5510c6efa0c79daf0c042a41fa29b717184d6010a7a01707	2022-08-23 21:26:56+00
163	154962	0xea07d0d23e82bfc1d51cf239cfc4c3f678f425c528855a7070d2475ae796fd95	2022-08-23 21:27:10+00
164	154963	0xe7f7c5f93bbe13bf799fc7255ff64067fbc911be3b4c2fa7dfdc76a461a86918	2022-08-23 21:27:22+00
165	154964	0xcd5bd4bcdd211a2d4ca5133479aef0e18d330c38d6135a03d36f8c93ed5e7e71	2022-08-23 21:27:28+00
166	154965	0xed67c73f0788c4e6f0e2badc09a26033c63fab257079b15b037230d7244b3570	2022-08-23 21:27:44+00
167	154966	0xa17f254d8f0413bcd65e5cf5537c8cfd1e642e16832f6f7a6d720e8b45637184	2022-08-23 21:27:54+00
168	154967	0x6616fb6d35b26ab71c33c9b26af955266f298687a75fb80951be5e5b5aa56e24	2022-08-23 21:28:09+00
169	154968	0x6efb7ade6e77d1084c46d80f56c94bf5126776cdcf4774ad5e7444cc9736de9a	2022-08-23 21:30:14+00
170	154969	0x034497366c599cf8eca55a4435a5f808e9db1dbea64fbce76f4584cf08645ec3	2022-08-23 21:32:20+00
171	154970	0xc9299797b644ae10c3d95d0a23249450cf22851534e67800e85adfc1647be157	2022-08-23 21:34:26+00
172	154971	0x2efb8311347027590f2a4e77643a39ae9d340ebff7e5f568e21fd222d5add71a	2022-08-23 21:36:32+00
173	154972	0x59cad7a954be0355b6ad47aa1c3c47073f8ea136dca4611e15943b9ffb7d0f9d	2022-08-23 21:38:38+00
174	154973	0x9d4233de183890a7300c221f63bbff524d24c5c573b1c78d9f9a89a6412e23fd	2022-08-23 21:40:44+00
175	154974	0xfa0ff2ab78f241a17cdddcb80b1453fecf5706cec812b6e10f0877273e010d68	2022-08-23 21:41:53+00
176	154975	0x81c28b33d493a9853ecdfe287ffd215d1154107ace1dc77e78230e8fbdd20142	2022-08-23 21:42:33+00
177	154976	0x26a83c25abf9255f3122f171a20ef26b0401a8e22d9305219c09a8f95dcaa179	2022-08-23 21:42:50+00
178	154977	0x532b07bcfd33c8fd107346a62c85b2aff991ea51a85c93ab69ac557c8ab7b7db	2022-08-23 21:44:56+00
179	154978	0x8e4577400c0c4fd47cdda3f9611965d29a16329563b61d470f04645229a75821	2022-08-23 21:47:02+00
180	154979	0xd5c1715f596c529674385edcdada12c39e8f3870761200c3104ce6da8a9bfa9f	2022-08-23 21:49:08+00
181	154980	0x2b3f1cf0721f227e1a05689e8949ca5dd70758b852845c1565569dbfe52cd7c4	2022-08-23 21:51:14+00
182	154981	0xda1d3201079d12559fe2b753e1e8840b7b93fa4af28ad4b3944c55e0b643443c	2022-08-23 21:52:56+00
183	154982	0x8ec62b40fdf8a35fa60d109d3d1f29e544d5d3de0fe1fe13a83aaaa48a62ec38	2022-08-23 21:53:20+00
184	154983	0x8ace2f4cb9e920413a80012bebcda55bca997d98a0303e36c8a2414e22b31a13	2022-08-23 21:55:26+00
185	154984	0xbf59568a992d34578a7f6d0a9a8450ce07bc7a55a1f397248e1a2560f16a9a8c	2022-08-23 21:57:32+00
186	154985	0xe31d2c0bfc84b4cf19fe4d90aa66f942538eab1ae2ca079d7073275b0975bc24	2022-08-23 21:59:37+00
187	154986	0xe7e4e4efcfb6d7acaa7ad71cb47760588d2ba4f96c5847344713f16b0e4e98ac	2022-08-23 22:01:43+00
188	154987	0x0d230cb8e60e7a961e9c70acd2100ed7eeafffc77b07b1f560a44063a16b31d7	2022-08-23 22:02:34+00
189	154988	0x8d76ba0d0ae14d2585d0aceb5e5228d31a015398a72875c71191a198e0449aa4	2022-08-23 22:03:49+00
190	154989	0x017f385827f6a16e251c1901fb4f64bb3a4a97f616abb9531ea0d636ec4dbe19	2022-08-23 22:05:51+00
191	154990	0x5333c5e5eeee190a00ea09105e9ca63e722a901bd87df7ea27165ec0baf89105	2022-08-23 22:07:08+00
192	154991	0x30b315ada492c0eeb0d394f8f727f20a9a5385a33ceb1fcb3c56cf6e4503f1c9	2022-08-23 22:07:57+00
193	154992	0xf12e265b1c711ebccd442059ae87a7d36b202c410d9519426e761ea7529473df	2022-08-23 22:10:03+00
194	154993	0x072d10adc9810b110a7bf6c30baf07f0586f0ab36289183250fc859d236a5f55	2022-08-23 22:11:56+00
195	154994	0x539f81848e664f3cc0ca81826bfdd1651e0f3bbe009ae4e95cbd08cc10d20755	2022-08-23 22:12:09+00
196	154995	0x33275d8824921a7cd1b85e7e635623677a922ec2713f6e6a0e6b76af5956a313	2022-08-23 22:12:24+00
197	154996	0x0be5ddee5eb7b39dc797366ca67c367b1e0a4676ec4a45b87ed833cc4e168485	2022-08-23 22:12:44+00
198	154997	0x7aa3f5756939b590b74026821c001a8621008987c73e67c5b1346561b93c4146	2022-08-23 22:13:04+00
199	154998	0x54c26530ea40b008846b03869a1220b733e26f205d98ea998ae753c4b7340a85	2022-08-23 22:13:25+00
200	154999	0xea3ed575bf4fa4c15cc54d832fdc801659c32cebbb5a46e140ba32a150465166	2022-08-23 22:13:43+00
201	155000	0x816c17c9ff9c1805f7038034fe6e2519e7efb4e75e50f5597ace933ac2c9e244	2022-08-23 22:14:05+00
202	155001	0x65a97eef7cc52129ccc27392657ea2c9ca187f22b62bece841968ba8fa797e80	2022-08-23 22:14:15+00
203	155002	0xd39a3ce296614651fbea7d07669237a03f320e4ed95f15e14b4e386512c1d9e4	2022-08-23 22:14:25+00
204	155003	0x6fd4ed1841ac50252da6da9d269ce3891d894e7f5600e1d002d58e074d4ecedc	2022-08-23 22:15:44+00
205	155004	0x30d3f96f82b2f13fc7bb12c97f4fea2dd21b4c6172be40095363cb93d3674d58	2022-08-23 22:16:07+00
206	155005	0x2d9d8d952c99f746415a356521d87f844a9912321aafa92fdcff0586c592bcab	2022-08-23 22:16:21+00
207	155006	0x16f1d045a56be694bba36e06e1d7653d8ac8134eb38c8435e5891b7afe9454e5	2022-08-23 22:16:28+00
208	155007	0xa8462ee2b7be2ffe0a513f2f819bfd5c0cc75f8f380f3a45f6eb575671032219	2022-08-23 22:16:56+00
209	155008	0x89042dd2bf7596331a7238bd80f7a18865ddcbbf6cc941e4576a2299f5799652	2022-08-23 22:17:39+00
210	155009	0x5f6a7baf87d24555a0f07e502710cf8da13c8c7e31f4ffbdefec73fdc324eb7b	2022-08-23 22:17:44+00
211	155010	0xa726109b533f4d97194db1147768d2f8a3007602bfe31004c5b9ee0aee96cb0e	2022-08-23 22:18:27+00
212	155011	0x6bcfff81a266ef653e525cb5f44c1d87c11cb09d0ecfb02155b4bcafe4588065	2022-08-23 22:19:28+00
213	155012	0xb3c30de0251283460886a7ae45138a6ed7b0bed5c57a6a8d48aac6170246130c	2022-08-23 22:19:42+00
214	155013	0x8acf117e7f2c462cd5e0295e537c847e5b1c06ff04a49c9af69631d17dcf002a	2022-08-23 22:19:52+00
215	155014	0x4ac061883aa7de584bac2efd9cd9304235479facfa810345ae8d568e10bdde90	2022-08-23 22:20:17+00
216	155015	0xd6588cfc67c9e4a701ac3bb35726023f11cc9baf668c5653be545ff608a59ed4	2022-08-23 22:20:33+00
217	155016	0xedff5a428f25866bc81f397ed95e6d44ccf869ba475e4932577b465fcc54e907	2022-08-23 22:20:34+00
218	155017	0x507c5e8d7c199276337c5ef5ea4054c61f7b7f251693ee2c3b979b0b4008a33f	2022-08-23 22:20:48+00
219	155018	0x6e70cc2eb3235627d715840d17ca215be4df7e937184aa8f42a940c10402bcdf	2022-08-23 22:21:06+00
220	155019	0x44a60a47f80a626977e066b0530d32024601a7904aacfe5f2b4fde632df5afa6	2022-08-23 22:21:28+00
221	155020	0xac859f01686c101ae6b5f5b88b7f7d50bac6248df35a34b783ee04c2fe1a431f	2022-08-23 22:21:49+00
222	155021	0xd4da570bb2ad733f7efbb10264c990d754922dd8af6238eebe7d732093936437	2022-08-23 22:22:09+00
223	155022	0x21292fb033eba3ce6dccb1d68231c670e78b9fbc6ed7ee2c832c8ae239761b33	2022-08-23 22:22:31+00
224	155023	0xce774942e99ed15b47ef363d9e5ad3429111725bcffc09a3a29cd1962e9364ab	2022-08-23 22:22:38+00
225	155024	0x45590c9623492a6fdde558507b4796bf4a5b967162167008649396ed92cd4913	2022-08-23 22:22:49+00
226	155025	0x5cc513b293ecb95723ee5506c9aadaaec0a75adfd3258dfbcbb0f55dfd190e52	2022-08-23 22:22:58+00
227	155026	0x67d655f38cfcb23ba089e9040f53b0bb2868044d52b55bc7b5037e56c1466f56	2022-08-23 22:23:09+00
228	155027	0xebeabe8e25b9a0fca5286b90133d98f6b3f648f13c10788ee5608f37312c954b	2022-08-23 22:23:29+00
229	155028	0x8d9877b2809f2d4fe7a02930d107767f1e018a76cc015bcc9aa10fbed5c39099	2022-08-23 22:23:51+00
230	155029	0x28e5960b8e15d1ba35b7e570020c9cc000e84c3ac0614280c7cdb0235e1e3c19	2022-08-23 22:24:10+00
231	155030	0xdf43ef4745de8e0234da0f4f2fd75566eaa7ec3dd7535a6cbd84903b880dce7d	2022-08-23 22:24:23+00
232	155031	0x9ac3abf59fc09f7433af67d0ad621a58f68c4b6b835faf188b402120115e89f0	2022-08-23 22:24:37+00
233	155032	0x6ec44a3b65ed24e6d4a78ef8971f831138ba8c3f075ece1f7a4da347f411e1ee	2022-08-23 22:24:44+00
234	155033	0x6e2aebea74c51f899744f182b0db3c855ff99bcc490106e572bcf7e8be197685	2022-08-23 22:24:51+00
235	155034	0x51c57d7d4c6e7e93eb5fb0f7c13e5b9d24f9c0343133da0addfee7319e0ed09d	2022-08-23 22:25:05+00
236	155035	0x2e8575e94137b3293934ec62271e05fc3b70c4de0df9101bfd759d6fbea7b942	2022-08-23 22:25:21+00
237	155036	0xd918212ecc8719ac2a09175b87dcec25eb115c1a4a6308d5eb67aa9a0ba69e10	2022-08-23 22:25:34+00
238	155037	0x10f2f5225ee4b177e3238450fd99389151cab96e7af6f5e8de72919a3c2c7f75	2022-08-23 22:25:54+00
239	155038	0x5ea6c1071cbdaa312a955fd9f822481c128cf8c8010b3e2a5d308f218f929a61	2022-08-23 22:26:09+00
240	155039	0x9b36be5e88f28a932e7dac89259ece4bde8bc67f4b4a6fae8f15e7686664d008	2022-08-23 22:26:20+00
241	155040	0x2cbe8991bef536786655097e700d7e1b7e8ea2f112163de36dca9d88bf620d26	2022-08-23 22:26:34+00
242	155041	0x12c6ca6c779a91d95086e111c30ef72ba5ad84afb2b05251a8d77672a7a58b51	2022-08-23 22:26:34+00
243	155042	0x64b9489215b2e536183a74d43fd85a46c1beee9ee0fcbcd243a2ef2f8f76b47c	2022-08-23 22:26:50+00
244	155043	0xbb93ae88e08163a38dc65d291bcb71a7dca8761ca65906bac542c2091659c6c0	2022-08-23 22:26:51+00
245	155044	0x27bfea7973c938ba5c4689569fd404a9a624a6e9419a61ad6026778c855ec1fd	2022-08-23 22:27:04+00
246	155045	0x5fc12e1d4c6fc6535c59ec7a19ea5a2f8c6d6eb03b4d97dbbcc11725514c78d2	2022-08-23 22:27:17+00
247	155046	0xbaee54edad24dac4c538db951f972944dec26284019a8361b5ce769761df006f	2022-08-23 22:27:45+00
248	155047	0xea29238184423d8f5dffd1cb8e0a25ade5b2e8f20268b33899f5e498af2f2901	2022-08-23 22:27:46+00
249	155048	0xdd0ed7842948d944061dbc31e6fbecc962b14f29b43969094c93a981f44ce249	2022-08-23 22:28:22+00
250	155049	0x820f30bc17c2d296858868d1289543a1e8d36d6a683d038c399b2eb1edc7305e	2022-08-23 22:28:23+00
251	155050	0x516baee2fa3249c13f1eea7ea3893708d1c3f07d18b02fd023ec7ee391c61794	2022-08-23 22:28:43+00
252	155051	0x662befb7096b308d9fceaa86e8c94d6cfd76a7444a57768c24d588723dfa9125	2022-08-23 22:28:56+00
253	155052	0xab10f3ca140db23b6260e7f544d9bbe686c51544aa560ce425e916bd691c6fe8	2022-08-23 22:29:04+00
254	155053	0x6533a5cbc6e69803f9833b456e0bb2864f6c8d805a8bb3a0f04902568482f804	2022-08-23 22:29:17+00
255	155054	0x79e0bf6bc364067868c4c6b7da22a1df4982b821f8ddefe247dbb956287dae4d	2022-08-23 22:29:23+00
256	155055	0x0f3756bc5569f3da8260accf47ad672f02d9022ba9709be2201041d8c2438c35	2022-08-23 22:29:43+00
257	155056	0xd06d0a4e4dab02be6457495e89e7456495b5194b9576de7ccf20ce3b5243e8d9	2022-08-23 22:29:44+00
258	155057	0x79143c71f7a82d354b4bdec6d0747f19213a4a51ab56082ca4d75f8b49e42ce5	2022-08-23 22:30:07+00
259	155058	0xf314108e67322218efbf65478a6ca62ef6512c19ebe5e16b4e84cda55725aa3d	2022-08-23 22:30:08+00
260	155059	0xeb99c14aa8fb8f821a57564ddc94834f93747d3b1fc7c72bd0c4f1213854557f	2022-08-23 22:30:42+00
261	155060	0x62176d91193307ed1f0d570d698cbc0333b8fd73a76112b540d69807ba58a33b	2022-08-23 22:30:43+00
262	155061	0x59b3e31d9bf10a70bcc4d37012728f825e5791e1eb37cfac8328e4af41a19cc8	2022-08-23 22:30:57+00
263	155062	0x41fb10805c4353fe44677bfc128ac50c9e9b64820e160f37459138123bcebae5	2022-08-23 22:31:02+00
264	155063	0x68884799d712109d64cc217db96f4b6dde4d042d45d11c21f7762eb721df1a62	2022-08-23 22:31:13+00
265	155064	0x8992708a5cb3e94c1295fd81a1cfc56aac613bffa8df630e6a45c48641301400	2022-08-23 22:31:28+00
266	155065	0x7e94e090f8cf5e296ac4b206cd480406e235be37888c707de60db3a18285a608	2022-08-23 22:31:42+00
267	155066	0x645be9536ca98031b57d731ab958f50860ef51081ffa37a0da203362c52b67e2	2022-08-23 22:31:59+00
268	155067	0x25fe99d9be5c2bf8fd8954b12ed627ffabb6d7e795a70db486345a9c98ee8f2e	2022-08-23 22:32:11+00
269	155068	0x75733c1ad65e91e101aa6319829b6cfd2103f7737f63210269ce67ec38815c60	2022-08-23 22:32:26+00
270	155069	0x4f88f5f37cdde87564f0551b208c5ee8c8e76ca7e864de943799bfff1822fe61	2022-08-23 22:32:39+00
271	155070	0x6c284169741793ead52e44c139fb19099d0e47ed6b5a25b812c8c2c7a77e427d	2022-08-23 22:32:52+00
272	155071	0xa3961994b572a39be8f1322c3d81add4f3acc46b913043e45d6d9847fb58169c	2022-08-23 22:33:06+00
273	155072	0xb83f61ec72759058612a7d6af1df9c5fcfc5c0b92b0b148efd93f35e5e98c3d8	2022-08-23 22:33:08+00
274	155073	0xed5b9d61380c039b9d121b3d6e76785b8447a9f58aa5df3fadd918db629f2342	2022-08-23 22:33:19+00
275	155074	0x980d0b9e7143bdd6ea7586dee7e7e6cfbd8e935ca8b7064496a97083845ec877	2022-08-23 22:33:33+00
276	155075	0x734d179c604f52fe087a717c417e32075055548b0c52d6a8bd231022555b2f9a	2022-08-23 22:33:46+00
277	155076	0xfedb9d60ae9a93153fada28bdac32a8f4bdc98cd4130c7d8af9b83b6adc6fca4	2022-08-23 22:34:08+00
278	155077	0x3082b817ced8653643fbc2485bfa797a09e3444113d3458d42c5343f5d6f4c28	2022-08-23 22:34:20+00
279	155078	0x4ea52e696806358fabb655bc245160291e045154f41967173b622b4c5e9a7466	2022-08-23 22:34:25+00
280	155079	0x14cbc6236f0bc25f4adcd1cca3f502b6841ce9ebf72cd3f42fe36e81f7430fa5	2022-08-23 22:34:42+00
281	155080	0xf15274045f9d17343540ad6adb18019e741d0b5dcb0958c68d7d2ebc2b66afdf	2022-08-23 22:34:43+00
282	155081	0x0ed74de2cd625c8ae66843fbe8c64a64d15d52b7c25fec1b106e458c8b9dfce4	2022-08-23 22:35:01+00
283	155082	0x11e59466d7f940bf5960585181170bb2cc8e303897c4788e1c97f289422d589b	2022-08-23 22:35:14+00
284	155083	0x28f68d780ef527edffb7c99126f3a68291df8b4e67087183a160e6968204e320	2022-08-23 22:35:20+00
285	155084	0x09203249be834886172f70b814967e8f006f51affe57ac6acb0a09e4cbd1fbe4	2022-08-23 22:35:40+00
286	155085	0xd3fa7560fca07cda87570ee503eef5bccd16105a52c07827db519c8ccebf3d88	2022-08-23 22:36:01+00
287	155086	0x4aec01154ad0f0ae0e5f5293fc3df25287489451ed4bedd3eb13b7aa040fa51c	2022-08-23 22:36:21+00
288	155087	0x204f8c576073e76ea54db8562132a440030576fb09e948bca50bdd5def6214af	2022-08-23 22:36:40+00
289	155088	0x5dc8fe6082686bd7d57dbc5d1fb92a9c82f6f1780df615b48007ee286a2a487d	2022-08-23 22:37:02+00
290	155089	0xfefff15989a9f178d82bcb0aca40cecdf552b17b6b08a310540a452f5f294b13	2022-08-23 22:37:20+00
291	155090	0x83f122ef84d922e746e8f9fabe84882a98606c0c5b9d5a2d62af3b43d4b65d20	2022-08-23 22:37:21+00
292	155091	0xa8d01e7e83ebb9b6afe3596aff86320771ff5dbadd5f90c923d2f33c1b204ba8	2022-08-23 22:37:42+00
293	155092	0xd53fcc7d5a7ca4528bc079ad52cf2e32a4e9275183c3fc742fa66b8122cb349a	2022-08-23 22:38:02+00
294	155093	0xbccb6c94461bfdceb1adb2da943277e8624b762c0fae88e8740a8ab5a58507c8	2022-08-23 22:38:22+00
295	155094	0x09fe4b2520cc450e8df7fb748c0dfb0552e34fe55474b0fe8e211c826b11e97f	2022-08-23 22:38:43+00
296	155095	0x8b70f6a2384d4b260daf952ab96f0b5432a5ad2e864bd5f768f5b03f55a3715a	2022-08-23 22:39:02+00
297	155096	0x824816878cb78be40e35658ea8e3bf4410ba9887d7eb8886e0af32b28c884487	2022-08-23 22:39:22+00
298	155097	0x8f8e38acc936b6e446f567668b9db0e9c0933f5e55eaeb90c1fa3e3bc12e43aa	2022-08-23 22:39:26+00
299	155098	0xffbd45792ffd451c7138a193409fc1a3c77846cdc333e6fce5c1df21ce19ddda	2022-08-23 22:39:43+00
300	155099	0xeef90840412eb6be080b5e6ed8f29247f828c0467800bf96cf8d572dc24d28e6	2022-08-23 22:40:03+00
301	155100	0x87eb52b71d3e1dffb92abf6b7aacfcf048488ae8d8c196cfbade18bea5d08b0b	2022-08-23 22:40:24+00
302	155101	0x640bb55d8bfcbac9c46c40b97c6cc3d092b76251fb9e8ecd90e6063b230fe0cf	2022-08-23 22:40:44+00
303	155102	0x2c444854779c6e0271ba608b3ac4716a2d746500a45badbb6afaeb80e59b6b1f	2022-08-23 22:41:03+00
304	155103	0xd5bf0ca0835392a43c02f0877848862f448fb70f425ec3ba61b58f9e3a85e00e	2022-08-23 22:41:24+00
305	155104	0xf7921f55e7f4ab7b168342ac259807058bcc0cc594528ebf20805dcfef54fab6	2022-08-23 22:41:32+00
306	155105	0x3a1bb7770068fec7932ca8addccf1551462fddd53fd1ae4cabe3f96532edc164	2022-08-23 22:41:44+00
307	155106	0x37af7c8fbbb0d6340721ee3cead4a9791a7bd477763d9bb8b010a33de63ff8dc	2022-08-23 22:42:04+00
308	155107	0xb0d2764263b4ebb2e36084e310f581a21528dda8b0b0387e09635e8374d91b20	2022-08-23 22:42:24+00
309	155108	0x770ab47286d0f52d14f73123e44ccc5f159805727d65dc7447d3e40c615baebb	2022-08-23 22:42:44+00
310	155109	0x862b007d204939fd246de553cee8e3a1271bdf59ee431b644a2d30a6b6e61c24	2022-08-23 22:43:38+00
311	155110	0xfddb5a72a9f26075e89b352fa2fac4d70037a83e0fd115443dc319be1d563bd8	2022-08-23 22:45:44+00
312	155111	0x6ee0649730ca6b4f137aea7efaa6c8487600ecb31dd14de471765d0622689791	2022-08-23 22:47:50+00
313	155112	0x371d636f05a4885f74e0eb4407fffb62aaf7ca2eb977e9ddcef9bcc20c6ec33b	2022-08-23 22:49:53+00
314	155113	0xfffc229f267d7563430be8920709890b299f519f5405733f974179921f8ce0d3	2022-08-23 22:51:58+00
315	155114	0x933f99307603f4c23348b6eb86dd79416bc2d663b578bf1b8799c31181626d69	2022-08-23 22:53:00+00
316	155115	0x19b20326f4e116581d3dc9770c64c45b34ba5d6ddd3f5dbf1fd00d1726a03f0a	2022-08-23 22:54:04+00
317	155116	0xf6c65f5f21963100f0303b9d988c1cd199f93bfdb4fcacd8c8e1f42c3aa8156b	2022-08-23 22:56:10+00
318	155117	0xa2f17c40cbad8434d23d295affb7c27ab64c9c478469b360d4430345c6ca6823	2022-08-23 22:58:16+00
319	155118	0x164b9cae6601665e5e42f913c07943f2df19ceb564d68c3ad1cac86b80ab8697	2022-08-23 23:00:22+00
320	155119	0x53f81aeffc11f9f4f27d7047325a50eb6fb2e142bc648a79ba97ca7c810c366e	2022-08-23 23:02:28+00
321	155120	0x94dd27ee898a9a4c5c2d4d5cfd6283f3fc7b7610b9221afbdc0a12e829baf4cd	2022-08-23 23:03:04+00
322	155121	0xaeaa4249aa36fe3f205922b846031e2131b2195c9d0810390573ed1ee089b183	2022-08-23 23:04:06+00
323	155122	0x0b3941f510713ed0ad5a029bb6e975ef30e79cfd5808ce3fdb990e826566c832	2022-08-23 23:04:34+00
324	155123	0x7f57a67d9b6c0c7301d1a924670592f63d265bb93530b27eea46b89c8400ff9a	2022-08-23 23:06:40+00
325	155124	0x75ab9201b58b4cde3aa0a33c49e9c43949564c4208cbb8840b2a5d9f06e96e88	2022-08-23 23:08:46+00
326	155125	0x3fe330729ef11a29fe3e298f492ffbd3df639b44872f0027b92081af7f2d73a4	2022-08-23 23:09:34+00
327	155126	0xcb8074f7eca5fdeac4893ddaac8f900dd82c12e90f6638b399a77b1a0c6dc317	2022-08-23 23:10:52+00
328	155127	0x28257ed45b925071556df5aa1fc9104891244696389dd9badd07045a77c8fa8e	2022-08-23 23:11:53+00
329	155128	0x4687797b608c4aabf24a42bff4e00fe42cefe6464d9d50ca3111b53d7f72df4e	2022-08-23 23:11:59+00
330	155129	0xf550b6249c564516890f3434667d08a74f772ae70a2c75d787a450ce7dd97d45	2022-08-23 23:12:58+00
331	155130	0x2aafde670bb878624925a73293bc6b1cacbddd6db7806659424f9f24c645a9b3	2022-08-23 23:15:00+00
332	155131	0x75850149ac4202fffca6deb52a10461a5e2b2c5cd1fe31d5c0b3b97916bef381	2022-08-23 23:15:04+00
333	155132	0xed2ece4249fa1ebd639e946c7363b1871d12ea7d71389aec202dd520e8c8c7b0	2022-08-23 23:16:59+00
334	155133	0x81d3f12bd5ff08ad15c1d694b1f4cea740e8c3bf0e2cdb9b6d80e7ec05cb7ea5	2022-08-23 23:17:10+00
335	155134	0x3b9fb9447f1dd7f201ae83dff2e8e2841638a69a4dd94a6722c8639eb2e3a129	2022-08-23 23:19:15+00
336	155135	0x3f7d562699cb16c2e513c0e2d0f4624c74477a63309f90022cadff8ff859a2e1	2022-08-23 23:20:24+00
337	155136	0xa945656a0a02f04ab23605140879705ce6b4dcc5ed6ff424ce70591490a4a7fd	2022-08-23 23:21:21+00
338	155137	0x96c23f714dd434bb4c2890d87148ca8f5342231cbd4e629c8853abb6a0b79ea4	2022-08-23 23:21:48+00
339	155138	0x047b07f1061a7c849d6dee7bebc7fd85dd78c6696a628cb4f4301bb288fbbba0	2022-08-23 23:23:02+00
340	155139	0x8b5b424958ae40d8afa4df596d6ca10923ca339e95a691bc9c9748cec8d0b3bc	2022-08-23 23:23:27+00
341	155140	0x4d2d98623bf251376f96f5f4e4efcf4334024b1d6a2f742bf70b594fe3cdf051	2022-08-23 23:25:33+00
342	155141	0xf1b33c040c565c26953e91f7d88b5894e321b26c7f45684550cb60ea7b3d8cde	2022-08-23 23:25:42+00
343	155142	0x1cd4bc05678868d259a9c2d7d82b328601456a28fb61480c82db0c07c2394ad8	2022-08-23 23:27:39+00
344	155143	0x45fc5be6de7c01b832bfa103b2b9670dff1991b9bad875c8190c8c7fb0ca2b1b	2022-08-23 23:27:49+00
345	155144	0x01a7556f46386c7efde701b792983fee9d91d62d7a7564e0bb1a08a0ce664c40	2022-08-23 23:27:49+00
346	155145	0xa22eddef49a9c4326930f7cf8a67574bd340a213f72b36c4117dfb76c6d04e66	2022-08-23 23:29:18+00
347	155146	0x4b681300441fb39cf213eb8351c4f6d11a2223a1816948fc7033ba962bc1fb3e	2022-08-23 23:29:38+00
348	155147	0x070d2ba5a3e3ee5e5c5af9dfdaa029a7f74d9ecc2f94d3f5aef0f09c82a00827	2022-08-23 23:29:45+00
349	155148	0x5a25f00c69316311e6340c8fbcd8ea4e2e1d1d2aa1b838f47cf895713583ddcd	2022-08-23 23:30:16+00
350	155149	0xd971adb5c3cc15b918a70cc46d4e816e7034b4fe3ac836b7cdd6cc6971731f4e	2022-08-23 23:31:38+00
351	155150	0x3eb1e2a7446162c9129b4432f816ba77034585da5fb5ad68561ac9ed12206c69	2022-08-23 23:31:51+00
352	155151	0x6837c0e5ca05243c21ee3ab89ba9e7e0c7e9028e21c6b6e51fe1a0a69f80ff54	2022-08-23 23:33:57+00
353	155152	0x80ae3683786d1877d75678fd3ac8a51fc48c361485b67f153171c7d5eb13da01	2022-08-23 23:36:03+00
354	155153	0xc431c7283a1ab666f0410e88ae854f75ed5151869ed9b935af32ba2f883eed59	2022-08-23 23:36:08+00
355	155154	0x1b34f3b0c987bf7ce5193ec92fef1f0183a776fa82329fc88a33729288ef9d09	2022-08-23 23:37:45+00
356	155155	0x1444b834eea8704f93c8aa535643e83b770a596c6c9d7879764822482a2e6bc8	2022-08-23 23:38:09+00
357	155156	0xe65c8760587aa9a5e035065211806af0c43ae9ce4c3f8fe0f9c229ea67c84609	2022-08-23 23:39:34+00
358	155157	0xc0745a3af121c337846d78884b9ae5ad472facdd161cc896e150be89ee743b52	2022-08-23 23:40:15+00
359	155158	0x05e51ccdf536e89867aa129cd4475ab1970fdb4d89e24631ccbd76d337032431	2022-08-23 23:42:21+00
360	155159	0x416c5b0e76dff5493938a434d1f97a579cac122a487e4bcb7946e35a817bfdc2	2022-08-23 23:42:21+00
361	155160	0x78ffd95b5d51277cea1949c570900dc873da1047c111e56a70648e616c772b94	2022-08-23 23:44:27+00
362	155161	0x8ee49271fde9203e8f713a34ad7ae4ae34d9a9cd3a6a358a4a580f898bca99c8	2022-08-23 23:46:33+00
363	155162	0x42d6e55a585f2593c8169c6548bd396fd81dbca187334a923e3739b6c449233b	2022-08-23 23:46:52+00
364	155163	0x343ff8752fb2dac9c51764481e3f643ef93eb450f1310b976cae5f0910d856f4	2022-08-23 23:48:39+00
365	155164	0xeb30badea0130aa99c25ef76dc357476a9d47e4cc6ae060849dd5bc5533866dc	2022-08-23 23:49:59+00
366	155165	0xfd2aa57b9381187a840eb16e8c800650c32dce493d5b29fc12169baab579b607	2022-08-23 23:50:40+00
367	155166	0xe27831ec35a711aa5c5b93ea68beed5f94c0093d8eed8011162975ade32dc3be	2022-08-23 23:50:44+00
368	155167	0xbe7424847cf573dd0cf904862c6deba47a11bacd7b5caef3b547837ec89b4f49	2022-08-23 23:51:13+00
369	155168	0x7f127d33edd5b19e0ac24a00bf3fe6e109beeca6b50d5299ef62e6ac458e1c74	2022-08-23 23:52:50+00
370	155169	0x6fe6b19e047f48620f31a459bfaa0710ed3b7956cf6cc57c62ceb222c845132b	2022-08-23 23:53:04+00
371	155170	0xaacce47cee0137d78d89a428c3633edebd2af76483032151dc7b4eacd2eea68c	2022-08-23 23:54:56+00
372	155171	0x220c2a51e9f403bba1a53503aa590915efdb56731f27ac6f0f49a50646bd6a07	2022-08-23 23:55:30+00
373	155172	0x3183cbf24ba3340c72e092b62245ed3f2e743e6d6c9d1d158ab89845168ad2ec	2022-08-23 23:56:03+00
374	155173	0x805626d499b2a3daaa3c76731f20c427971b30724e21120bba306e4a16d8601a	2022-08-23 23:57:02+00
375	155174	0x27a0bb7176f7002e063e96ab27fda54712b0cfffec4bd5dea4e8e4b3bff7a8e1	2022-08-23 23:59:08+00
376	155175	0xce09009e3eaa885962d0caaf91add7c08a4299b0eed39d7577711a2f735b2bd5	2022-08-23 23:59:17+00
377	155176	0x43f697485a4f3bab76cb9d86fd774630a4860f5be5cc5750f9b8f5aaa1a257a2	2022-08-24 00:01:14+00
378	155177	0x58e763572f37fa887d55b546f7a1ba79b154c041e8b2323949b1626cf2661bdd	2022-08-24 00:03:20+00
379	155178	0x0469d05392034fdbf04fe07f91448dfd65761ef42fc72e9e35ffacab26ece926	2022-08-24 00:03:34+00
380	155179	0xc01806f0c783aec88692d63f46a344d0555327f392a54f25dc3a1209ceda81e8	2022-08-24 00:03:40+00
381	155180	0x40b03c177a323c8a1ec70c5b436bc90645d3553e10d890bd571106951b7b6812	2022-08-24 00:04:14+00
382	155181	0x815d41d1b78c27446f9634c7bab039657ca4d49c329e86399c47b2769b9ce471	2022-08-24 00:05:26+00
383	155182	0x660169934a94f6fdee76507b2bad2135d989b5a8ccd8aa205a8ced557ab64dba	2022-08-24 00:06:38+00
384	155183	0x14816a4c5c93573be0bc7c9b1302acff6faabc06455caeee688e3560b7b14e00	2022-08-24 00:06:41+00
385	155184	0xd9e1144bc40d892a28108aa46cc8b208e77207217ecd667db79024bf1a591131	2022-08-24 00:07:14+00
386	155185	0x06d5bf327ebc86e1543af6bc998f7ecd18ee4014fba8e5b1d96b0ac82ae01939	2022-08-24 00:07:32+00
387	155186	0xc1f3c0ea83ae3c66ebdb2f0c4649792afeec1fd57885e67bbdceb7488562946b	2022-08-24 00:08:19+00
388	155187	0x6212478e93f2defef64cabe2866ec938680b35211be28ac381f77ae71583112e	2022-08-24 00:09:35+00
389	155188	0xc98279522984c6fec8fcf980ef2eafac7fd094b5c7ffc00b8b11c5ccf466c494	2022-08-24 00:09:38+00
390	155189	0x7c9eeaeb2b2ccdb3bf51b990cd7909ffb719424a98814d89b58d45540ea241cd	2022-08-24 00:09:38+00
391	155190	0x8fe97792bdbc0ac3bac04ada99aff4331c42390282c212ac58007da6db89e3cb	2022-08-24 00:10:11+00
392	155191	0xa309336f1ebdbd8721d6618d66ff61345c7ed95d94edfcc141dc433f731f9895	2022-08-24 00:11:44+00
393	155192	0x60fe8713471bad94598e988a263f40432cf6bc452ad0830c47391dab9d3da2f9	2022-08-24 00:13:49+00
394	155193	0x1dff97008ecc63d1e1d07b73cb1bb880e146d90ab3e95314fa571c6de9b739d8	2022-08-24 00:15:05+00
395	155194	0xaa65dbdc9298bdba7a71673deebc254b1557ef5f7a308fecd461db683a1860a7	2022-08-24 00:15:06+00
396	155195	0x112888f200d0215df4968f37312a140c613fb5c27934abbfe52c2af8cacffd22	2022-08-24 00:15:55+00
397	155196	0xc035a58373d1b59bbef815fb5883b347e73e217d56ef8057c912023ba7bd841c	2022-08-24 00:16:58+00
398	155197	0xb50a82223c94055c8dbe9be3bf4c2dacd7e81aa100f639ef5f03c3eb918d789d	2022-08-24 00:17:32+00
399	155198	0xb994cd4877e6e49ce4e742b79b6b0ff505fc5809721bd5f9f649528f529ced90	2022-08-24 00:18:01+00
400	155199	0xbfee2ffd478d502c0f24ce37a63724db36eb175578af2fcb4883450e1fca1e98	2022-08-24 00:20:07+00
401	155200	0x90a6498d6fc2e3f4d593a99c5fde6b8c4f2b468e20656a6485af13b47545e109	2022-08-24 00:22:13+00
402	155201	0x6e28f31b1c4394352ab57e7c3d58f94ee45d7917933d00087cb627ae705a3eb2	2022-08-24 00:23:05+00
403	155202	0x5d18d7d684e2cb2f78098d70d77bca3ab436b3a99b771fc9c31c95a116e646fe	2022-08-24 00:24:19+00
404	155203	0xe5cfdf38b1a8618263518f3655bb0fb82d73cde57db3403af7a374e2bf00153f	2022-08-24 00:26:14+00
405	155204	0xbcff8199f824ed7b48deecb8817f25cf8c412c8aab701b76ef7f51271fd1b3aa	2022-08-24 00:26:21+00
406	155205	0x6d9a56a8a02ac86f693290c1291a3ca607fbeb61e51c36fbeda56cccf24db92f	2022-08-24 00:26:25+00
407	155206	0xf77b3a1294088caf0a8968b957f5ea140db1956a9238187f1ccae62dcf0dd81b	2022-08-24 00:28:31+00
408	155207	0x3a0419e94e5371bf297c37136597b94ffd9c4d993b45d47eb0372e9e8b1b18ff	2022-08-24 00:28:31+00
409	155208	0xfdce82069109edec3f5f02ea228fde67c70385921db656fa19e0f5c637a8fc5e	2022-08-24 00:29:17+00
410	155209	0x4a9f0f83ad1da94f6e41e9f01f8e078e2d1f1cb694ebd5145298fa0a4c3467fd	2022-08-24 00:30:37+00
411	155210	0x442e1ee54caa98c80aa5f20e655a012c0c84efaaf960a5c683029912d3638f6f	2022-08-24 00:32:43+00
412	155211	0xab6819c60e11df843a76076487d17a0784f8d6c504e763eeaa4a13d4ef27f1b4	2022-08-24 00:34:27+00
413	155212	0xd32284c0bb49bc3affc0dbfd0404d79a47981ad5473051b7e651d08ac9d52d77	2022-08-24 00:34:49+00
414	155213	0x3e3df498f2a6a07d30f375bbb8009d5c56caa8bd10fa1ba8b8680f1b9b17b75a	2022-08-24 00:36:55+00
415	155214	0xb7c09a78c66f8aedc3baccafbbd99858b09efb8be1fef81b68e12b45706bea49	2022-08-24 00:39:01+00
416	155215	0x7cb821868a427616d702b38d2f4b4b4d5805c1e67740f67a5edc422cbead9fb2	2022-08-24 00:41:06+00
417	155216	0xc70714f9756f848b6ebfad89bfdefc07a531b763152f93333b6ef86518b92d46	2022-08-24 00:43:12+00
418	155217	0x02ff38b6439751cbc5d3e62452b3278eab0db487f5ee043ec2df33bb6e1b0e88	2022-08-24 00:45:18+00
419	155218	0x35d54812555b661a5f2a9af9f1f8cca4d26589763304a60bfd6f3f0a7f9c8da3	2022-08-24 00:47:24+00
420	155219	0x27300876b86ab5530a7b3c4e32212dc9271b65a72d2527cd3312bdf54df5af38	2022-08-24 00:49:30+00
421	155220	0xa4bac70b3cb0c8ec41632677b36f42658ea16135bd55e3d9cd31cef263e58aa4	2022-08-24 00:51:36+00
422	155221	0x2239eeba33ac98e2ee272f9a6323d9c7477e55867a61a4a9e4de4df1df780ced	2022-08-24 00:53:07+00
423	155222	0xca55f6545420331a3ee98b1c066f376a5f0c038da1e83555a0422d9036620e60	2022-08-24 00:53:42+00
424	155223	0x204b35f8375845d2d9f4cfe950fc0bc1a4cca3b2ad281ebaeb7b0c531e12a8dc	2022-08-24 00:54:44+00
425	155224	0xdf35caa77c4fb4c59bb6105db08a641a45625e3be982de80a817eb7fe0ecd75b	2022-08-24 00:55:18+00
426	155225	0x9b0a64d218928d5bb302cf4c77f9533bbc4e95c7895e9669200c98e43fbb3311	2022-08-24 00:55:48+00
427	155226	0x3ee1a59e9eef5a18abb7ebfb4ab3b94939620cd5e1211f45769b29138d2736c1	2022-08-24 00:56:40+00
428	155227	0x50c8534ffd413aa1c9d4aab60e3ed5b670ae2d6aff8e7f2368eb4988d2a969a9	2022-08-24 00:57:13+00
429	155228	0x9b2c1be65cb31258f59ff427dee0db70d7c0f373cc727cf914a43d21fe719b23	2022-08-24 00:57:54+00
430	155229	0xb3183d517fde7ea42b45af547b496bef6267e75afa08a3edca51985615ead6ee	2022-08-24 00:58:41+00
431	155230	0xf345189c5d133c5637c43cf3153fadfd8a80669d7584337930269db8e580f51d	2022-08-24 01:00:00+00
432	155231	0x3d11005e6f8256618a6721d8632429e7a27e388cf9f9d0346156b2bf7e86cafb	2022-08-24 01:01:39+00
433	155232	0x05024b6f5c64bf04889b1e3043582cdff7f109ed0273579deb61c497b8bdee67	2022-08-24 01:02:06+00
434	155233	0x6eaac7ad51985753f95120437e50078c693f5f0ea2dcd3cfe70dfd215056da99	2022-08-24 01:04:04+00
435	155234	0x6fa1f379b6ecf12f5ed7912a6a6c295429d5ab4c125ebe346df4c15935df4344	2022-08-24 01:04:12+00
436	155235	0xc6325852f0e91621907bb8c5f9d555d8e96df8ad1f6e70a69023cf59ad845b4b	2022-08-24 01:05:55+00
437	155236	0xc6d171a59c3048f5e891888a901ac093b5001b5232a97dad87f6d2b99a63588f	2022-08-24 01:06:18+00
438	155237	0x2b8549afb9ca612ba1763cbf3694a38c5088be0a789728a9e0c6f7a780073966	2022-08-24 01:06:29+00
439	155238	0xcbc8368b9115ad73ea277679511de4ed22ac7a209f81de58ffd01f13a2be040d	2022-08-24 01:08:23+00
440	155239	0xd8549258bd6d3a5f1ca35164712c3f1486f2fd81e7ad37f9a95595843af42c99	2022-08-24 01:10:29+00
441	155240	0x9c45c60f4e058c73c7c60ebddd98248988f2b8fcf8d42c7b9b14be019b36983d	2022-08-24 01:12:35+00
442	155241	0x7a45fc009ecf1b6ac6354b89e2b79677f0d22e24c2d67d75fd232de90548826c	2022-08-24 01:14:41+00
443	155242	0xcb326c744d3386b9721439deaac6db86aed49c887db521478281b3b3d6523f2d	2022-08-24 01:16:47+00
444	155243	0x20d3d2d719ed4361927be2cb7edd61e983aa969d9862fd747307e5ba4ab5230c	2022-08-24 01:18:34+00
445	155244	0x707787e18a09082952a575ae4d130b5d6df0579840c7411d767bd6f8f35910d7	2022-08-24 01:18:53+00
446	155245	0xeba5d08f4cbb8b18359833e7624d5a5879525353e362d57a0c3b8cf75ba58611	2022-08-24 01:20:59+00
447	155246	0x30016c34be75fcc1bce57bc1f4243b65138637b1af2bc344573ee9deed801bc0	2022-08-24 01:23:05+00
448	155247	0x2e3b34f99fbc648b83c014e1ae3d0633ba457cd226ce49ce565ef841895bc1fe	2022-08-24 01:23:09+00
449	155248	0x5ccce66cc14c9980d5bfd36779df9cce8e3ffce45a2f360be2217142b76ca8bc	2022-08-24 01:25:11+00
450	155249	0xd4363e5a073163474b997c93f1f5534b9089c011c174b5f185933dbeecceaabe	2022-08-24 01:27:17+00
451	155250	0x3f2ca1aa787192503fac79b5e445102cf14d1c0deb672b0f55da4a8d6bfb2a25	2022-08-24 01:29:13+00
452	155251	0x4197aad791bbb070f4962e5e036ea4ae054b10664990e85eeee32dcefdd7aa81	2022-08-24 01:29:22+00
453	155252	0xfdde44c8fd6ad78794590efb68f49ec9374e5b1482cf5d301f93f73fcb71efe4	2022-08-24 01:29:22+00
454	155253	0x599ff358dc9729ed5fb4b08a7e80622dad085179859f845065ad2968607a5eb0	2022-08-24 01:31:28+00
455	155254	0x31e78e13d3c95484975e5edfb67e48d0480fe98ce2c638bee5b9805740f0fae1	2022-08-24 01:31:51+00
456	155255	0x937c36f78cdb7000106c45af8913dc0f5ac9a418f8ba0bd4271a39c8b989224c	2022-08-24 01:33:34+00
457	155256	0xc251cf85a2e5acfaf693c19f290606fe2910561cf857707841d4f08062049e11	2022-08-24 01:35:40+00
458	155257	0x69fdce78688f71a709e3471899530f68be93e3934a85bb58ba9861b9269f7525	2022-08-24 01:35:45+00
459	155258	0x089c04d5ec807957a1c5c07d2c44a8909a8bd507bae1295a59c4989959d43322	2022-08-24 01:36:18+00
460	155259	0x607fd61637b3f6ca341b68f9fb2ad68437b1e3164e2314bed75c9822817a97dd	2022-08-24 01:37:46+00
461	155260	0xe263b33192ebae4176e4639fbcb9690f4b1c3f4c65f632a092d7e04879f75c5c	2022-08-24 01:38:57+00
462	155261	0x2084974ae4732491408a6a08c97d800a387b36a418a056d4d01cad3d6d21f54b	2022-08-24 01:39:31+00
463	155262	0x82821ca8564e7fda0a318c475c8d35ad473238a82de4691ba12d17d38eae8567	2022-08-24 01:39:52+00
464	155263	0x3b7b140be3826f71ff2003580858fb6bdc8be90119741deb8cd36b9920ad54fd	2022-08-24 01:41:58+00
465	155264	0xc11d2d457d7074a08fb545036321e4f3899b4d1087efbb1e698cb173603bc0ed	2022-08-24 01:44:04+00
466	155265	0xf994266f7e2b3a66e137a8491fbb1a8c3d9c76c4e6cd1031c4f3be90798e4082	2022-08-24 01:46:10+00
467	155266	0xdb5479dd579f9ef507da18954bb6217c3b9d5a5505475798cd462ff1b4f480b0	2022-08-24 01:48:16+00
468	155267	0xa2c05b031b3ded4021bcabf635a3768ea34602d2a6fd4cb08fab738cbc435d31	2022-08-24 01:50:22+00
469	155268	0xcd54a705dc47b3f9c8765187892ad8ee58eda5ebb3cb58c11bb6e92c148e1d40	2022-08-24 01:50:39+00
470	155269	0xac169a71fab015999f5e9a0ccc36ea911687bc1c1fe1b114008f33161c457fe8	2022-08-24 01:51:13+00
471	155270	0x5157d314d8a64aed04314e31baf696c997b5b714f42cf6c319ebfa6e5361e8d1	2022-08-24 01:52:28+00
472	155271	0xdc38b1e757e68478e5d20c3689e6463410e902ac1e05394de0be0f0b17370fdd	2022-08-24 01:52:53+00
473	155272	0x0bad90fa31770f805425e40b346de147e21e2c2c235862cbc0693e44160a2daf	2022-08-24 01:53:15+00
474	155273	0x817340af07b50e5dc6ca12752d9a81c12496b2589ab8cc161b1c415a4a34cded	2022-08-24 01:53:30+00
475	155274	0x464ee9b42fd272377a1d89f9ef1ab968ceef4421c2944ff91427704a42d009a9	2022-08-24 01:54:03+00
476	155275	0xf32ede360fb4aa2b865fe9148dff9eded8ef50924a7d9f3b92a9a853bf2faae7	2022-08-24 01:54:59+00
477	155276	0xacfb986681a9a5117e2f0c00e84436f73fabf38c7dc28ecb3a18ea8986381015	2022-08-24 01:57:05+00
478	155277	0x78234bd7fae3197c190bd257be88f6e02c4272eb02a5bfd4d6dbcfbe08b59fe1	2022-08-24 01:59:10+00
479	155278	0x64192b841fab448630778892d3719a88ad161d5bbf7a805acf6e22b8d9f06b81	2022-08-24 01:59:12+00
480	155279	0x2a390e263ac225a47b646bc07af52369b3f055a3cf3953e171d6790e8790e50f	2022-08-24 02:01:16+00
481	155280	0x9e9df729aa11cad7254570a7db90e842688c5818d773e74512cee4b435b1bf19	2022-08-24 02:03:22+00
482	155281	0x0d69e780e311954857398dc1f2075013ec5a1e4e51cc85ea06aa34c7e7a8e168	2022-08-24 02:04:34+00
483	155282	0xb7b6c60a8385676014205ed3f8556a53e17d941d2e5ae958d0afb3aab27fcae7	2022-08-24 02:05:28+00
484	155283	0xc9fd8d51f9bafc3816377deb81d3bd52576c7639524b66e4a37283a8714a4147	2022-08-24 02:07:34+00
485	155284	0x1e87524c2353a6ebde62034fb410d65b8f7121554c0495ea1ea257f1b2166c7f	2022-08-24 02:09:40+00
486	155285	0x1d205c493055e53a75dc73a51c2fad441b19af07bcd73c5a9b1a063cec65148e	2022-08-24 02:11:46+00
487	155286	0x372ee168886dea9f4c23bd761a4a5ad0dfaa098ac2d677515d67678929a6b54b	2022-08-24 02:13:52+00
488	155287	0xe438b3cb5549d86fc98014af1d0277371c43235b800268f4fb28735bdcec5594	2022-08-24 02:14:24+00
489	155288	0x0a13f2fcc0c7b767c92fc36361d97e65284128100955f5d277e3425a8ac948ce	2022-08-24 02:14:57+00
490	155289	0x4fcec02543710e750d77054d06b1d6c83aaab203423746f816ca649fbe5e51d5	2022-08-24 02:15:58+00
491	155290	0xf8a521f5c4cdd9d9235a0b4a6022b412cb3aa196416c2c590293b6e84ca641fa	2022-08-24 02:15:58+00
492	155291	0x7eaa62fbd2ea29ad14dfd3081ba02b8a82947537d07242a124333eab6acc4529	2022-08-24 02:18:04+00
493	155292	0xd67b65965ad370f7a4e364dfc81a3e55220edd284d84d796ad9f3c731966fc72	2022-08-24 02:18:48+00
494	155293	0x4b19b02a9fa8d5baaf7eb252262d8f9d2bbfa9bf75f014946d318ce07243ad11	2022-08-24 02:19:00+00
495	155294	0x098e129e70cfaa389c0f39ec0c4c574cd0183dfb9c783e9f2022f2195d659a65	2022-08-24 02:19:08+00
496	155295	0x3ab05b2bb888a6c599d3d5eeacb991b5a1d6ec44a162177cdd33da0e85bc8ec9	2022-08-24 02:19:15+00
497	155296	0x2f763fe01cf3d7907f6bb2602108867581951e9d891a0fe6794c21114adefc22	2022-08-24 02:19:23+00
498	155297	0xeb1d1075e51096163915fc01f60239f492ce59707a20d1b15cf4a1895e804c67	2022-08-24 02:19:29+00
499	155298	0xf647d1164c4e858a5d4642b5595786eedef570e5863d88e16131feae285d0875	2022-08-24 02:19:36+00
500	155299	0x393e532558cf506d4157eb958441c3a8f56b66a895771a1e350ea9d540cf0539	2022-08-24 02:19:41+00
501	155300	0x3a8a869bf9008ab62d883fd0ac94008527ce45c7277a5f1d12fc3ae31d25a2a5	2022-08-24 02:20:10+00
502	155301	0x7701588578cfcce919ae4ad184f1da5b57413ab9a80dbe4f4d9738c1c0ec46bb	2022-08-24 02:20:20+00
503	155302	0xae63b695bb3233111b45fac78152541bfeb17f2be07a4a3ace5ea9457b492814	2022-08-24 02:20:47+00
504	155303	0x480f7110002a35f863c1ece835a3e890b873c084c712d0aa242deaebc766c51c	2022-08-24 02:22:16+00
505	155304	0x005eaf96e4acb2ae2a0c4d0f9c81d087fdcc4384e4040b4abf4d0263baeb13cc	2022-08-24 02:22:34+00
506	155305	0x7b56c2504efd7b17fbb9e554311865c153327e795483f00ff9b6674c9838c763	2022-08-24 02:22:45+00
507	155306	0x16cbabcac517b74e8a0ee94d58ee472b16dee1cecfc78b943e984ed2130fb810	2022-08-24 02:22:53+00
508	155307	0x7df125a98e39353af4e4ceea6efe20c16073935270cbb7ce00ee5402fe4eab33	2022-08-24 02:23:00+00
509	155308	0x5ba0ac56281e2d4f71465bdab723b4cb1b02c4fa0d2e9f930d164cec8253c8a4	2022-08-24 02:23:07+00
510	155309	0xa6181289d7c8366b24c6bc2d0a03f1bf4791436e25546d1c4715e2af769463bd	2022-08-24 02:23:13+00
511	155310	0x648803b20275b186d0b4dab694b39360bab8c0d2cf2250b7822031d2ba9a6fb1	2022-08-24 02:23:16+00
512	155311	0xda15919b6cccc714f45d814330acb5cbf4f2e0af4b3186ef73bb20858c4abc4d	2022-08-24 02:23:20+00
513	155312	0x04b0c39770fb0e9a2d1d02787c0d8eb1c529063e473c5b199ac1cc8469e31d4e	2022-08-24 02:23:26+00
514	155313	0xa5caf561c486f89a6838ac4c8780119df0fa72d34e155052a2d52a4ebc2ff896	2022-08-24 02:23:33+00
515	155314	0x785237256f069451965d7e50a9fe9a33979a763384906ae6ac90ee3f84662287	2022-08-24 02:23:40+00
516	155315	0x67103f4ef09add1a2caec52f46066d86f2d7f9dd6572f7605d2704872bfc700c	2022-08-24 02:23:51+00
517	155316	0xb4f67a548678bd0e5f0ffca474ab4861504ba2cf782d637b753adf3feac004de	2022-08-24 02:24:22+00
518	155317	0x8284540b386921a85ebf1739bb96e86b4cb4e6f88d8c2613dfd61cdf02ce09a2	2022-08-24 02:25:42+00
519	155318	0xd2c31472fe764a8f1354ccf701a88fa710dda9f19b5ce134db12b81535363116	2022-08-24 02:26:28+00
520	155319	0xc34c75dcc4fcf64373a5de3fb8b7fab98b7f95babd275741e58897cfe91467a7	2022-08-24 02:26:32+00
521	155320	0xda2977dbcf07ba6499ce779b61e756fbe224af9ff398efd5c5c87dbbb7b30928	2022-08-24 02:27:12+00
522	155321	0xbba732ef55737043f42854f9aca09ae8127d25dfe31e756e12fcf27778afcbb7	2022-08-24 02:28:08+00
523	155322	0x755944766732bd2b7cea16e19afd12946694474b96bb967489dbd761e9aee944	2022-08-24 02:28:34+00
524	155323	0xa56e9030f0bf1a683616cd3e358702d949df108c246ef889f976826fcaab2adf	2022-08-24 02:28:43+00
525	155324	0xa868ffe3c4f698c61795363faa9a268c2c610464d745cada55b88f34ba5ef788	2022-08-24 02:30:40+00
526	155325	0x683d9f2a5e8daf58f63ccb444ffcebe2510f88a08760c97df3ed417a6bc8de68	2022-08-24 02:32:46+00
527	155326	0xbe722dfe874c4040e29c855aa052e2dc8398f8ed2cebaaa749260735ba65c327	2022-08-24 02:33:12+00
528	155327	0x8cea3c86527137849a53539e8f10de5d493b4761001128914e5128e65b0f84e4	2022-08-24 02:33:43+00
529	155328	0x97b3b579f7c565ea4ef775b63d41f0d6f26fb8673c2ca09b6db35134a2f13004	2022-08-24 02:33:55+00
530	155329	0x49f90a06f0811ae1a4ec30b21a06fc67b84de6d49256bd16c82e8c99c1912f0c	2022-08-24 02:33:55+00
531	155330	0xd9bd0f3fd6ac9aa2372070980658c6105b7765993f489d1bae70e326ac8d5c19	2022-08-24 02:34:17+00
532	155331	0xf709935244c58e8838bca45c3f9ae370b93e3e27924312a8b58f084236fad874	2022-08-24 02:34:48+00
533	155332	0x70be9e525abe2fd09c741ae8ddf806e1768f16d7b55fceb0219b0336e3d4335f	2022-08-24 02:34:52+00
534	155333	0xa5856d2a93905b6b684de30e55ff738ff2f508ae7c0637f3a36e8a60cd5924a6	2022-08-24 02:35:14+00
535	155334	0x89e8bc46abd9f5336f303b7a1d9b0ce2e7932a6965a6addce1c26aa4b5bb3eaa	2022-08-24 02:35:46+00
536	155335	0x2f252bcfb146b6e93f67da33ee17b7beb628dbb415bd5232e5f040a0dfa9d728	2022-08-24 02:36:13+00
537	155336	0x6c6a5eb9bf72548b38af3d292fa8bce351511c5bce461f738fbe5ee82d99095e	2022-08-24 02:36:39+00
538	155337	0x90567896ab051d6dda5f13e0e3682d033663b6ebc922ba160315de37f94504ff	2022-08-24 02:36:42+00
539	155338	0x7b0bb930ebdb19f5e581143db3e950258502ce5a427378e3e555d65a969a9462	2022-08-24 02:36:58+00
540	155339	0x3e6798d51430f5d02a4628d14c3a834d25081d58d447b6b85880ea5fb6e0af16	2022-08-24 02:36:58+00
541	155340	0x804f6d113b4860c2f6cacf7b1fc3059ee99584d5e86a87f725f86dfc16bc1b23	2022-08-24 02:36:58+00
542	155341	0x3c26bd3e45d8b88da0282ae359e6e883f45fdc0693820b0ba7fff5f6dc83ce53	2022-08-24 02:37:19+00
543	155342	0xa51e5e8e21c58ecd253d3f97401e6043cae4526e295c13f46d7ce50f2744ef03	2022-08-24 02:37:57+00
544	155343	0x873afcade5205e24798aab11894a198c29059658a0a196114efcb44b7a914717	2022-08-24 02:37:57+00
545	155344	0x9d1260ff08283a8af0c5bf40a33e9bf601e075a07b7168fae48496456bda613d	2022-08-24 02:38:27+00
546	155345	0xcd6b4c87d6eef67b7754abb7f1200db41c7c8986f07f222e9e8f28676c947991	2022-08-24 02:38:59+00
547	155346	0xa8bc977234bf07bd80ba0aba7a41342da9859ff958d4cb63649d77c165248763	2022-08-24 02:39:04+00
548	155347	0xfc2b92366705d4ee5ec2d7e53add4737dc110c697cec9a3f1bd3f646c483e233	2022-08-24 02:39:47+00
549	155348	0x83bbdda048a24d4dd8763ce18ee5e5b2f070ec16726f7c32acd51df7ebf3e662	2022-08-24 02:41:10+00
550	155349	0x3bfb685c47441d1a9d9f375d1f4d4f86e569d5cef00bb6d772eb68799e16f4f5	2022-08-24 02:41:10+00
551	155350	0x6331aa6cfc831b8d3b1367598f9dfbf924bf3d8e08d98d416cbaca93649b60bd	2022-08-24 02:43:16+00
552	155351	0x093036f357e18a47d0f285263439d676d2884b147bc0e3c722e242743d44b2fb	2022-08-24 02:43:16+00
553	155352	0x9c7418d921fab75b4f21c8e4a7d7e0e17d3e30a96a681a31b0fe9eabdbb692a6	2022-08-24 02:45:22+00
554	155353	0xef9ed0cf59d068b4211c834d528ee0bccc2297adcf22b093832a29c2779d1961	2022-08-24 02:46:27+00
555	155354	0xf493acaf81ac07a511a7fd044dc83074a5bb75c7581c1ac93b93def9b32e09af	2022-08-24 02:46:38+00
556	155355	0x4bc16a18ba3687d487ae38f8b4c208b419216511e313ea13fae659d98558dfd2	2022-08-24 02:47:28+00
557	155356	0x1f736cb25eb37fa80c802fa5c57ad2868365e46ae623bbd181e8b0e8ec2e1b5a	2022-08-24 02:49:13+00
558	155357	0x3728bcc8ad4ada27976fd8248ff3ae9c1622e06d001935a175fbb772c081f38d	2022-08-24 02:49:34+00
559	155358	0xe618a16e1881ce426e32cdafe6c81c9aadcb0b823ee83d80d481c04fafbd80a8	2022-08-24 02:51:40+00
560	155359	0x4cc7553602d0442aa5728c4df19fc9fb078be69d8e713df7778ef3f12a3eaa66	2022-08-24 02:53:18+00
561	155360	0x7e28107edf9f78765539bfe986f38dff206cc400b6c81b8b8a0eccf46b42bd12	2022-08-24 02:53:46+00
562	155361	0x46aca9e06cf0b14483ad7249e69fbf198ad6015a47700899316b29594ef7bad5	2022-08-24 02:55:52+00
563	155362	0x6b93a646e72d1b667e18dc671b5b16b098db503ab5edcf1b79a2096594949fd6	2022-08-24 02:56:39+00
564	155363	0x04d3cbacf6d204d573f4b2b7561ef4eaa11499ef40d4e7daadf4badbb6d403df	2022-08-24 02:57:58+00
565	155364	0xa0938edfc186d6535d393ee722bf6547e8f489bcc6de092f8ca3a98bf6a0d0db	2022-08-24 02:58:01+00
566	155365	0x11e9bcc04e8da174cdb9a39256b2395a2505cfdc6a866206cb7aebe387d736f0	2022-08-24 02:58:47+00
567	155366	0x902effbfa92294f2f0932ff2ea3cc2e879d15eb90b82c429ceb545cc5d98ab06	2022-08-24 03:00:04+00
568	155367	0x6dd562011c484ff86649df3e8c1c51bb2fd0fa9ecde27f00dddb434bf31458c5	2022-08-24 03:02:10+00
569	155368	0x54e7b4542000e616240f840dc78df4c766b84efd0686f3fe4ba4c184d3fad56d	2022-08-24 03:04:16+00
570	155369	0x88903f8d5f12a0550e3c847204f5ce8a0e6e81ee364df82b6c74694abd868156	2022-08-24 03:04:58+00
571	155370	0xdccc0c1372498d07858c132479e839e50cde7f1324bfe89fe9fbbe6f636f4b88	2022-08-24 03:05:04+00
572	155371	0x775d2b5bfd5d3f9e82ed98c4e2c444e8f0611d9241800675e0cf575afe97ad1b	2022-08-24 03:05:05+00
573	155372	0xd1a4acc8b7ea46655e0045a20c93d4db228120633edbfb08af21399d661c369e	2022-08-24 03:06:22+00
574	155373	0xd0f10d53168d1af4e31132315c6f66d5c95ec333082f0d20c2de74deb4e76908	2022-08-24 03:06:57+00
575	155374	0x9603ace29df253e7943cd2cfe329c9255214cd0dc8ddecb3dabe61fb9337623b	2022-08-24 03:08:28+00
576	155375	0x190b68714549340292388a9e201dbabea58bebb41c51d43c979cc60bd01d4ce8	2022-08-24 03:10:20+00
577	155376	0xa35525d5452a729d4cd1d1221dc5294ea5b2dc02a2b7756d0db8f453d02a18dc	2022-08-24 03:10:34+00
578	155377	0xa593d540ca7bb1799288ed7aaa5eb5e173e7d3bb0e799dc2906599e49ca0d617	2022-08-24 03:11:01+00
579	155378	0xf9352c344a3c60d604df34b61e9c8e3bc44a288f1f61f51d4aaa54c2a0f8a962	2022-08-24 03:12:05+00
580	155379	0xd8f445131bf43bbe25fbb4cc7f651a7f817d6f3c16f004415181af7907dfbc88	2022-08-24 03:12:19+00
581	155380	0xb2fa1ab24e4721ba8d75dbd44202377d1b85d68b849494473531f11d7064d1b1	2022-08-24 03:12:21+00
582	155381	0xfa936ff3dbc8042fc805da3acbddecdad5c1b8d36d2d606109c72e02e9c26c53	2022-08-24 03:12:39+00
583	155382	0x60873d07a4eac4919a4b17b15c43e2a691c16df76b961db87bb9b413737e975d	2022-08-24 03:12:41+00
584	155383	0x4e70b9e98cf18226756cd13f7428f0ff9ea045bff216490de61e4bf462a8c5d9	2022-08-24 03:12:46+00
585	155384	0x26ecc4d606e2cc15e1eb791c1463c871b810f926f8b3c05251a41fe6c8270990	2022-08-24 03:12:48+00
586	155385	0x5cca7a1d57b20d132d022b13b4f073761dad04df9fc621a7984ac662ce8f4034	2022-08-24 03:13:14+00
587	155386	0x03bc8a35df8eeda873fc72f60bb63e236d1453e51c2d8ae3596fdb2af9f93427	2022-08-24 03:13:14+00
588	155387	0x1ceb523e47d7eccd05fa6ff1a41ab80e54475f26cc997cd304317e811f7a6556	2022-08-24 03:13:15+00
589	155388	0xd18a20227ec3684ad3ecc198b96147345508cd11aaa595998417aeb5a51d4314	2022-08-24 03:13:36+00
590	155389	0x928ff9aab059a34b233adf80e2a9820c107020eb292f5149ebcafe5c9c95b64e	2022-08-24 03:13:36+00
591	155390	0xadcfcf6657ead4a363d39acf83cc5f67530474593bba435913f53998be67543b	2022-08-24 03:13:47+00
592	155391	0xb1e11fa9a6e9388c1664f59cb12294db38bd03f6c7d128d47b12bbbcbf1f3704	2022-08-24 03:14:04+00
593	155392	0x25b4aa52a8cedffcd825b144a2c46b06a3925ef99657e034e23749e0485197e1	2022-08-24 03:14:07+00
594	155393	0x1b46384930dbfa3651f4117fd8c5a57ebb05e84c4f145b95bba0d1605525630b	2022-08-24 03:14:16+00
595	155394	0x18576d5dd2be649e753567847a6d01c12818166432286e39aec91738af2022eb	2022-08-24 03:14:42+00
596	155395	0x1f5c482883b73e6d763b89fc7950669fb442923038c252ac75222dc5fcf515d0	2022-08-24 03:14:45+00
597	155396	0xdf091a2c158d3494ef127581ed06dff474ad4a35dfb7479e295193f9d4aec380	2022-08-24 03:14:48+00
598	155397	0x1914542ab54244b6c490f2dc8ff6c5dc655d23f1ca2090d82dcced50ed3a1757	2022-08-24 03:14:49+00
599	155398	0xd0ad063f29611cbd4a16e0be3d64872b0cd664d96f27f53291bca1d53368e0b6	2022-08-24 03:15:10+00
600	155399	0x63144a5bcb5eed1104a40ac92bd46bc83ff22b9247c59c04030f844792b048a6	2022-08-24 03:15:16+00
601	155400	0xaabf2a0b7725b20efa1cb1861920b24da5cfa34fd64ba6d349dba18ca48d9c1d	2022-08-24 03:15:17+00
602	155401	0xbb6104ae3533bdec17d4f393f45ee1439b46959a70b934189425fe4a24eef44d	2022-08-24 03:15:38+00
603	155402	0x8a9c4202e82ddc8e480d70c3412e51b36ba71dd4ea99e16649ef20b78ac6344b	2022-08-24 03:15:46+00
604	155403	0x037720edbdf16a23c9e3547423f55a48850d5ccc1963a59a035642921d7e98f0	2022-08-24 03:15:46+00
605	155404	0xf838ab9427b49d46332ec2180d7c37e4ddb22b9a3f4864f73661ffd1891dec04	2022-08-24 03:16:12+00
606	155405	0x9ef79a87306f0d9200fb64e9d218584f01cf36f954c0c3d20722880f2c4e8c5c	2022-08-24 03:16:18+00
607	155406	0xb4c75f056f9a190a5f671bdb8bba39a75362c0d9a8a5d5607a9720f575b74df5	2022-08-24 03:16:19+00
608	155407	0x1681ae1212b052047f1e22d3e82f8d7662e4ce1ba06065990cec54daddf0efad	2022-08-24 03:16:36+00
609	155408	0x9ccf3b790ada7d6297d86f70619d707920953ce01d53664b28b19e88634fa5d8	2022-08-24 03:16:49+00
610	155409	0x645aef4494b24d5920bbf46504b6ebf2f60a0554cfa097b67c449883a0f9b4e2	2022-08-24 03:16:50+00
611	155410	0x880fed28be198528fea36f325c848501a2b9295b047aa46fcd450dcd610d388f	2022-08-24 03:16:51+00
612	155411	0x77440111ecb197395ccff2e2509d1e567c0f86b456fe8c94a7871f3b032d980c	2022-08-24 03:17:06+00
613	155412	0x65e8631c70f7b3544c70cc0882dce2a255433bfc8667d35c163a1d500e3ee30a	2022-08-24 03:17:16+00
614	155413	0xaaea57dcf01ce3d53ce2b5ab80fc64fc7a8d0438cac0b17a34fafb96fddf8b1c	2022-08-24 03:17:24+00
615	155414	0x21009edb6db98099c4f75ae6b95c00b1c83063daee8b75e4a877cd5240d9c767	2022-08-24 03:17:44+00
616	155415	0xd3ba47efa9c0b65c57c9ab5cf0670233f31b469a0748e3882107ce9072e2a3d1	2022-08-24 03:17:53+00
617	155416	0xe6143207e75ddcdfc58abc7556a05cfc6b64075db13e42e152192d9024152ec1	2022-08-24 03:18:07+00
618	155417	0x174308f09a4d65dfce3a745b05e4ce548c22f52dea6343f539108b3c51ef6595	2022-08-24 03:18:14+00
619	155418	0x1903acb377da73eb0db3a2ca5ba21ee3e49bdfdae0b5ce1a78e08ab07ee790e3	2022-08-24 03:18:29+00
620	155419	0x6f004b53cd33d967da2964356f28b467f19885772c7dcddb2e0fdedb9d88df56	2022-08-24 03:18:33+00
621	155420	0xffe9a89e2ba2ebf2e0c9e01a0c8c42123eb6d452c98c0857f9c7469653536ad5	2022-08-24 03:18:53+00
622	155421	0x38be22303d2a6e0f01a1312bd3b394fdfac36fe8a5b99c1228dc979133420ff9	2022-08-24 03:18:57+00
623	155422	0x135686051a2dbe902475db67ba230f1fb27f47d6f781011d0a1064329a7b572b	2022-08-24 03:19:11+00
624	155423	0xa6ac5586ec5ffb0895c66b2fffda8d1ba6efbcf503309affd76f541d7cbba8ab	2022-08-24 03:19:31+00
625	155424	0x51e55fb960f254ab870344704240f49f06b7a8b535ead7266de8af6b61bde6d4	2022-08-24 03:19:49+00
626	155425	0xb5a25ad3ea87d075c620f1eb32f7470bc079fb49eb4caa1e2649b6d79b7d6dbf	2022-08-24 03:20:30+00
627	155426	0x6309dea8f88015eeb18012b35c601515e26cd4dfd210340b624516c7ab22214c	2022-08-24 03:20:31+00
628	155427	0x44786483e68baf7d20d6848652366b5b92127e2841e5624378dbef0fb9ae00eb	2022-08-24 03:20:32+00
629	155428	0x9171ca5e112d2edec020ecf3083008d1cffb07667049e9a14ddfe3761fe59264	2022-08-24 03:21:03+00
630	155429	0x800d4cb659493fbe730086562ffe98344c93e4cf11c68605d63678966444dda0	2022-08-24 03:21:03+00
631	155430	0xa018cbe6518b096155cc171b6c5fc23ad5ef058dbb5ebf68ee6dc661d51ec61c	2022-08-24 03:21:04+00
632	155431	0xadd069f4cd6fead0246707437b097bc3acb7b8a3d983e3a393464aca066b4b9b	2022-08-24 03:21:05+00
633	155432	0xb14979644b0615ff6b0b792fe1002020207028a83b46ea90556c54f79e2bc8d9	2022-08-24 03:21:25+00
634	155433	0x188e49002ec722115388965215a735f7c734241664ee0f0b492eb3b5fc721ba2	2022-08-24 03:21:39+00
635	155434	0xb11f626b4c57da49b2e23d24fc0336082eb23a99bf9babbb5eed2c1bca44116d	2022-08-24 03:21:41+00
636	155435	0x094b7cec31c310619157f6385a4d758e965c39e940dece8a1c59f54bba7aed4d	2022-08-24 03:22:10+00
637	155436	0x9fc5916d5b1478c31adb59c74a1518894bcc21bed728db754658c80ede247a26	2022-08-24 03:22:11+00
638	155437	0x6f0f4b2b1ce29a0602584562ab502b76f932b94b15d33ade6b8d6f0976646ae8	2022-08-24 03:22:13+00
639	155438	0x82ccdb34d3c03e7879b20970170ce5ea727a2c7cc6d91befdd8db6fa45ba8d29	2022-08-24 03:22:32+00
640	155439	0xa69828ba45ce0d100d9ab345e602be1ce3567f41fd1baa150b12e3bd3bf4d7d2	2022-08-24 03:22:44+00
641	155440	0x5ef67fcd8da204deb09847dc53a8f1b7ba4725b40906cd1bfcbce7ebee335775	2022-08-24 03:22:45+00
642	155441	0xf3e1d82cea31e574318079f80ed7237ae5086a9d0e5a2068e331001a85a5fa1d	2022-08-24 03:22:45+00
643	155442	0xe20717464493937facc1fef55ac8fbecdae8eaba2b5a1cba39799d47f54f86a0	2022-08-24 03:23:09+00
644	155443	0xdcbac8085fad960bec4ef55af72678af36865b257cf091a0e184a95752c9a465	2022-08-24 03:23:16+00
645	155444	0xe50148d6038804732e2c606f809f888a89efe122a3e25e6b24007b11339f48d0	2022-08-24 03:23:17+00
646	155445	0x442ddc17f273696f8b232e3d965d1add30e90f024e74550fae9dfe562cee5af2	2022-08-24 03:23:18+00
647	155446	0xe6f522b2797ffe677da794fb6762e518d50c2b3decc6d598b621a4f563749d9b	2022-08-24 03:23:24+00
648	155447	0xcbff1d7b9dd008055d5555f68428373bddce08347345851246d908c74049684f	2022-08-24 03:23:47+00
649	155448	0x2395603b555aea209618a1dd157bdde7bd6a473351761d6ec9c836468b83dfb8	2022-08-24 03:23:48+00
650	155449	0x9ac87d14fe44d0fcc91b932d56ba29612b1db97335093f718207fb4d2b5988fa	2022-08-24 03:23:49+00
651	155450	0x7cc8e22b0717237c042d58e0c0ff8a9cae5a5b15a204c9981dd2b9c9d5e27166	2022-08-24 03:24:30+00
652	155451	0x5144bc022bd358462bcb3589271e735522233e6e7e94599106e470412f2a1496	2022-08-24 03:24:30+00
653	155452	0x0d68fdeacbb78e28815bb136108e0a2f25fa33117e5941bfd66ba8a1211b89e0	2022-08-24 03:24:31+00
654	155453	0xf77eb907dfd191174fe71280f2ef90b62eba820a35fb73b2e881d8f5ba67973e	2022-08-24 03:25:15+00
655	155454	0xe2228b0728258403347223165792b6fb0ebed81ec7db1195bc625a0ae86c71fe	2022-08-24 03:25:15+00
656	155455	0x32c7b29bdc60403fcb9b8d5a9ddb3e0971047e5f5412f403b5ec74f44c239b6a	2022-08-24 03:25:15+00
657	155456	0x56931d0a8180e5f4acb46fb89629af977de90ff898e9fe7ee42095d2f9c4c162	2022-08-24 03:25:18+00
658	155457	0xe0c7d9a26dd32f9458c484a8136094329c7526a20f044ad3445f29e481f53a82	2022-08-24 03:25:20+00
659	155458	0xc043707c2bc135e352f5ce7c724d1336d3c3db09b47a18d656b5fb680e123c76	2022-08-24 03:25:45+00
660	155459	0x783b2a23aef20349c72376af2c15c0427474014fc1682b3608564f885f2c0af6	2022-08-24 03:25:46+00
661	155460	0xd2cb6b0421ac253240377c7c384e257aa690eab195e5e95f428926bccaec21eb	2022-08-24 03:25:48+00
662	155461	0x0c51c5570c6c0963e45b5ac79fba39389d7d15174ceb88c798e86f50c3895b1a	2022-08-24 03:26:17+00
663	155462	0xde5bf4ba468755118444993b4bc70037ca33c1aa36c5b6cee312c5ebf9388a6f	2022-08-24 03:26:18+00
664	155463	0x1e521647d934914ee07bfaa5ad11790f58248a0c4999d2cd10fdfc3d420c9498	2022-08-24 03:26:20+00
665	155464	0x25d18602c7296cf15b030e5fc1b247a800399f9eaad4f70771589676b879efc8	2022-08-24 03:26:52+00
666	155465	0x3e9bf9c58f42aaf5d63f682263e4494d31d9488f6c4f73c02858036a4f0a299a	2022-08-24 03:26:53+00
667	155466	0xbcf540c4ad7d90a472f2abca826386fc600fc6318a2c0bbc00e08c06365b2f32	2022-08-24 03:26:53+00
668	155467	0x3555c649bc995e8b4d74eee0526462c2b53dce52ac60311175dc5068f8891798	2022-08-24 03:27:05+00
669	155468	0xf9b4711851d5a66bbf4bd7c6b928d6e99323367a7f19ece3e786943a657e2d0d	2022-08-24 03:27:09+00
670	155469	0x2f9f157aebcc2dd265129550d5ce6d73a9abfaeb2293d9e84aabfba2f6789165	2022-08-24 03:27:11+00
671	155470	0x9b6773a849971d800d8887d9b1436209e6ef1dd49b936331e2e203147ae08b70	2022-08-24 03:27:21+00
672	155471	0xb83dcfdb48cc2f8f00832910decf9c1e6acfcd787d917235338136084c515f39	2022-08-24 03:27:21+00
673	155472	0xc2444614d0fc29d9bab1a41a6ccb11226c9683e0e868868c2ca9d2d7c915c7be	2022-08-24 03:27:23+00
674	155473	0xdda0d10ab2099afe65edd1d0ea91a7688dda49fd9f014b46a4a969df8b8ebeca	2022-08-24 03:27:24+00
675	155474	0xd5c1e6f8e5969d2f22cef0c0781639f7928f01ed54c92e7936c361e8709e60f4	2022-08-24 03:28:06+00
676	155475	0x8618e12f0a043810c307b70eadbef936ebcc882694c1dfb6bbe092dbdd810ba6	2022-08-24 03:28:06+00
677	155476	0x6f4b04e22087de07084d91655b1fa899a6fd299d6f8d6dd96c13bb51407e05a3	2022-08-24 03:28:09+00
678	155477	0x32b50ee927bb1d7d3d08285e85a10640f783b7b7a2bdccdb8d5c24ac242c7748	2022-08-24 03:28:51+00
679	155478	0x46453252c575905308d3b75f81f0c1ef6b8aceecc3493edf86e7e628c396cce8	2022-08-24 03:28:52+00
680	155479	0xd0c1c5736d631bbf5cd38061e59ed58338a3da22f3edb12db7617b308a23db4c	2022-08-24 03:28:55+00
681	155480	0x9f6491e6a0804939facd34de7a8a3db7962a2125ef74ac8fd642c1d9bab60258	2022-08-24 03:29:26+00
682	155481	0x8cffe70876c4fdc66532467341f6eae5327b0ac06ef682636373db11b97471f3	2022-08-24 03:29:26+00
683	155482	0x886b5ef79154073e2e21196ad236dde49287b3f1ff1cb45a9972e52e130493ea	2022-08-24 03:29:27+00
684	155483	0x2565c86ab3e0bf23c2e86c29a40a7d266b041c226caa4adba72c6e6265cd95f7	2022-08-24 03:29:29+00
685	155484	0xf5f59dfa04381609fa60f3101b9e2410e425e89f4134ad1455d13191dcb9e4fa	2022-08-24 03:29:31+00
686	155485	0x040a9f9a982b4363594d1180f3bf94e2d830df4f7af2bf1eb621ff01720481e8	2022-08-24 03:29:39+00
687	155486	0xd15d2e1ee3f5291732603c129208443ea90bc96c200547285fa33b91834d87e7	2022-08-24 03:29:47+00
688	155487	0x6fc9359d913fab62a9ca63a516ce5e30227eb5fa83709a6528b0ce0f0580085b	2022-08-24 03:29:55+00
689	155488	0xf55eacd9beba38398de3c41154770078eeb1360863520e6115d655102ac1fbbc	2022-08-24 03:29:57+00
690	155489	0xb779847f9cada64c6a1942ea63a6d2cdd63a2c735baea8c3b1f3e0bbc37f75ed	2022-08-24 03:29:58+00
691	155490	0xa8b2981039dd0253b12bf2ef6d7f89ef430fd42f6bb718a56eb011e64ba5fb7d	2022-08-24 03:30:05+00
692	155491	0xb6cd99bc04b9784606c5df41cc67dcf70bc29f4bd6646922eda074c101a46be8	2022-08-24 03:30:34+00
693	155492	0xea247a67bcf2dc8531eb19e45da5df4fbd771feffb0510a760467b53c73fb55c	2022-08-24 03:30:34+00
694	155493	0xb2e3086447917598d0cfd1dab297b169cd650757aeba91fd210f72abef4e7a9c	2022-08-24 03:30:36+00
695	155494	0x3949e61ffa45714314aa3b93fccaa9762b11de41e90f3773bfc0369790c3dc17	2022-08-24 03:31:04+00
696	155495	0x10c103685f4d3863625973e38c21f49837e2372064ea4babac797aeaa48af431	2022-08-24 03:31:04+00
697	155496	0x5246c70eec9acf53660ad68d2a09bbc90b066787a7923dba3d65feff21eba1fc	2022-08-24 03:31:07+00
698	155497	0x8e79b8967550e49481be25d463f0c4134365923ca575243486f08dc9ffda7d37	2022-08-24 03:31:33+00
699	155498	0xee77a3eac3afc9f449a5cc69f41134d57ea6cfd18327181251b694bb7377b841	2022-08-24 03:31:36+00
700	155499	0xe7dbd0b66cfbd4aab1503d10a2122dcef21fa19749e746eb3facfb573e84c692	2022-08-24 03:31:36+00
701	155500	0x451d047bf3f14d75b7324df1e119525a4ac30ef67bde6f64b29913755861fcc0	2022-08-24 03:31:37+00
702	155501	0x3732050dbe1f78ccd9ad4894620876425f983414276ee15b2af6a2bec9f59368	2022-08-24 03:32:13+00
703	155502	0x023e38ffc28c3fe89655c08377429b7c5cab3fd4e66453da09ae4d9834ec48e5	2022-08-24 03:32:14+00
704	155503	0x4f19fdb15ea90718c789749b0e52d90319fd74ed2e8a65141f5e57e7e3c4410a	2022-08-24 03:32:17+00
705	155504	0x08094ec9143b09088ba8d0e64c644fa614d59e134c9d43edea15b86159029403	2022-08-24 03:32:46+00
706	155505	0xa3ad7403e1e9a3ed570d4b3663657cf71a3fa466b933b1dd3919fc0aac1ed765	2022-08-24 03:32:47+00
707	155506	0x208f66e21535e56700bf61c63d93c1cf89fe99b0007cbf778e9c69d08d7b15b8	2022-08-24 03:32:49+00
708	155507	0xbe5c1cc8323d7709e50a9d4c40ed6352074e593b2c3a10e9e00ad9942862dc93	2022-08-24 03:33:21+00
709	155508	0xf96374c7f1d3c8410fcf168fe0b264c954b603514785101ba51f032d3412ba92	2022-08-24 03:33:21+00
710	155509	0x7341c7b23bc5e6f49f51bc07e487716e1a0be98fe7630f1e08d7f9399c85635f	2022-08-24 03:33:22+00
711	155510	0xbf835e9a4b5131202f6155c09f70deddce2e4c72a736e4b8f76cc5106bf84164	2022-08-24 03:33:39+00
712	155511	0xec31148bf421e1852b74616a0bdfdd893fccbf21e67988fd8b0a8a642c3f50a9	2022-08-24 03:33:48+00
713	155512	0xf72b93e9ca994ecadbc67100e7a5ff1a0e829b3e350ce79179834e7aa0d6d396	2022-08-24 03:34:08+00
714	155513	0xce38a63f1cb2ab3743048ae64e6912106f2ea199c5e5b6eceba6b22e8a403471	2022-08-24 03:34:08+00
715	155514	0x0c7b7088be340ba2f0fc74e4678fec069c23631ccbbcd960c2f62d3bae730e66	2022-08-24 03:34:11+00
716	155515	0xc19c8dd29ccca655f0ee2df86bee3567ec401c260c7d15868807ebe84fcf03c8	2022-08-24 03:34:40+00
717	155516	0xfdfa32a702f3ea1ea230192d8cc5c09c38bd7d3d7a4798dd790c5931b218c2cb	2022-08-24 03:34:41+00
718	155517	0x33cfd9cb1e048f287485a35f3adbc0e90de62542c1a6e0663db3ab3d19d6100f	2022-08-24 03:34:42+00
719	155518	0x6a1b41a1a8f27945f55bba8232a9ea0fb0021b5b5b8683eb45ef54df40426c01	2022-08-24 03:34:59+00
720	155519	0x3d507bbf1cc8261878bfd8ad3307de43631d4237e6467d5469bfdbcc61100824	2022-08-24 03:34:59+00
721	155520	0xfd80992225215bb989db57d8677829df11cf92d8844fbe29e7f4f5042ee17a4c	2022-08-24 03:35:15+00
722	155521	0x4022b81daa4d3d350d30d70175e56ef2a36c0520ef872d1fbda2a332cfd8b5ea	2022-08-24 03:35:18+00
723	155522	0x0d868056d9e1c0e64058805fb05cb407e52007a148413b94921cf8d45a0852cb	2022-08-24 03:35:33+00
724	155523	0x801a3ccacbf2054f363df3415369439a7065b75f0d7ee4539c7b72fd8613ac2e	2022-08-24 03:35:33+00
725	155524	0xadeecd201aad0704d42cf89853587b511a405d368950ce3f5034bb7f6a6394f8	2022-08-24 03:35:45+00
726	155525	0x5d944ed67796649a0742380bac0da92ab6c6993cd7da9d4b201be1eaada22989	2022-08-24 03:35:46+00
727	155526	0x4fe08f9aace8c81a4a34584b1c4b745197464a535bbfa3e73e0bb8b6f29b2ecc	2022-08-24 03:35:49+00
728	155527	0x60e71cf01b5eb503e8a5f4200b0dbb957e42732726fcbb132996f562604d3f75	2022-08-24 03:36:22+00
729	155528	0xd83b9ba06318ee27cd90de0b0cd47f858604f7c003d8e32e7510827e8834e457	2022-08-24 03:36:23+00
730	155529	0xe9424d68965275907c5de4c9b18d8658a0d4df8eb47a34ebac628f84729893cb	2022-08-24 03:36:25+00
731	155530	0x94864a8d60e2a1426b442c0affbf2427f09081a314dfc7240bda90269cf78232	2022-08-24 03:36:54+00
732	155531	0xc4eae013e8c91c97adac0e620892277faea1b78709a5b07f889de5d245ca1d7d	2022-08-24 03:36:55+00
733	155532	0x5a3d3ad224ecde0373db25987f502c21adeff579d9f99d16212513eb41e5d1e4	2022-08-24 03:36:57+00
734	155533	0xdb1a9d3900c7514a243a3e08936b2ed892c0cdc204436eaf1e86dd85238e4198	2022-08-24 03:37:26+00
735	155534	0x1c14da45d525677d8bb9a41d7f28ebf53e2f4461cdf0a696d5bd8b0d89b4ebe7	2022-08-24 03:37:27+00
736	155535	0xc1c36b26139e8d0bc015bb3eba97637a56bd9f5a6bfaaf5d0ecb20c2b6de8af9	2022-08-24 03:37:28+00
737	155536	0x7a1e8dd6703182f23a0835a561c44c99f1186fb1e9d40448541afb9bb85c5539	2022-08-24 03:37:46+00
738	155537	0x694e775b40c28036cff935625f8f116fc5271d7081320112d7f435a8c5c62b13	2022-08-24 03:37:51+00
739	155538	0x9afa0c862f2ee5550a7f1684b3f38877dfcc6ddeb7c8911d9a8299b18a23f066	2022-08-24 03:39:57+00
740	155539	0x940c4754343c2a9e32222ebc3694c632d75b1a6939ba97dbed4b355672032daf	2022-08-24 03:39:59+00
741	155540	0x7ccee8fd3f4ba0813c1f0e746d66405b4d972b078c40b17a1ac93c680f046d9a	2022-08-24 03:40:00+00
742	155541	0x72388c73b09cad040e96d2f7ebcccda47dd4233b00af974500d3ce414301e942	2022-08-24 03:40:02+00
743	155542	0xe84b44a04107da5a653904602f93c48155da3fa7f6565bd6344530374e1af8af	2022-08-24 03:40:13+00
744	155543	0xba749312d50a8b0b25ef3f3499c38a4c4738ad318a1134445bd419da8859e70e	2022-08-24 03:40:37+00
745	155544	0xfb4826620ed16fa9df78d4cb5d016e5a426e1266695e339ed166e1f789967373	2022-08-24 03:40:38+00
746	155545	0x5697e3f69c030c276bfcb3f763e1a5f85f15a5a89b4e34978bef0487ff9d3d9d	2022-08-24 03:40:46+00
747	155546	0xb9bb9adf880e5c5947d337739c4a03a997708e9de4d4cb93cc6d456e17337165	2022-08-24 03:40:50+00
748	155547	0x33274f9625617e4c2d62fb5556d187b98ec8bd6cdb003e34f01aab5a156f21d1	2022-08-24 03:41:09+00
749	155548	0x33b400a333548a3d32523672a0a30aeb60bffee18e42267a794d2de10668ab25	2022-08-24 03:41:37+00
750	155549	0x637d211fa353309dd56bc95d2fc49a6c93650bcb549fafb9cbe67703267d9a0e	2022-08-24 03:41:38+00
751	155550	0xb4ec47833a42b7accebcefe69745c838aa5b1de68a9108c05b793c421f2210bf	2022-08-24 03:41:40+00
752	155551	0x4cb4b4af36824697c2d24882a115f4255505a9006a83fb12b78f7a56ec54e097	2022-08-24 03:41:59+00
753	155552	0xb274e82d6e11ae899496b6332b4f1f293b2edde6f929dce41f76cc8bdcdc9cc4	2022-08-24 03:42:03+00
754	155553	0xe1011fbff8441b352dd7d22c0d57928db41f180d710a4150f4fc99da72fe06a6	2022-08-24 03:42:15+00
755	155554	0x66f170f20f670b503c514ea5ed9647cb70f2738cb027fe18e932a600adf0c1e3	2022-08-24 03:42:22+00
756	155555	0xe098e6ea9e5d9ec9a732f2fc2719197f3784332192f3c6d0a1fbf890e9510689	2022-08-24 03:42:46+00
757	155556	0xd7523e5334ae1fca08c0e1377a87882053528c8a4291d991fe2cf21a904f8809	2022-08-24 03:42:47+00
758	155557	0x53b22fc3d2e7e568d30068dfa570387d7fa6a9c1a900078fdcb7d698928e37b7	2022-08-24 03:42:50+00
759	155558	0x629b7f85676654d8a6f045034832822b21ae948437224fa6f35669e567c74c9e	2022-08-24 03:44:09+00
760	155559	0xe4d96c25dfa26403f423d049b19b3752d2939b288dc340f32e494d61f60653b8	2022-08-24 03:45:49+00
761	155560	0xdab8b4d767f2854e35edbbe3b2ef6b58326e7bb560ba68433100542093548818	2022-08-24 03:46:15+00
762	155561	0x9832e72783c608a9d0ca5eafab4758e3fa43517454de60b48204c76b0f38ce0c	2022-08-24 03:46:39+00
763	155562	0xce8dc84c6af86656c0dbf904bed18dd41c29c28284532d58d6a7313610959f15	2022-08-24 03:47:11+00
764	155563	0xbe6f4691e4e0d0e7c24530ec5fda7e516cef4681afc0bd373ea8a1ec70218b4a	2022-08-24 03:49:17+00
765	155564	0x7c9b001577e092d02291d364875c6f33e49e530e5a9be98562bd4a7ea4c16421	2022-08-24 03:51:23+00
766	155565	0x0d477445786582909b758678f6d112bfa8343fe3089aeeb49eacfdee5c25cdc0	2022-08-24 03:52:39+00
767	155566	0x69618f5bd028b25136e1d644b5b19b570a153d127529f73f093132dbb7125517	2022-08-24 03:53:25+00
768	155567	0x2a13ca7e5a42e8e395aa2d560ed80b8a79eb863838ad23d9e542664e5aaa26d8	2022-08-24 03:53:29+00
769	155568	0x53553651ef5019b956f90e7b6432e96258cf91fea3a2129a6c76939900fee506	2022-08-24 03:55:34+00
770	155569	0xde5baa8bcee56a21e379612cd6c1653ddc14fb729c47ab2943370212e5593642	2022-08-24 03:56:22+00
771	155570	0xd2ead907d9962ac6e145a4f940bacd55744e6f6349b9edb47381a2977ddedf71	2022-08-24 03:57:40+00
772	155571	0x2afda9353bda7ec384b3198453f0b4e6e96bb8d9965025645ff5a2f57ef45466	2022-08-24 03:59:46+00
773	155572	0xe7928615ec48ff6b663b6cf13b0f0e6bed8171c4a5a560ddc4afb3a77717d603	2022-08-24 03:59:46+00
774	155573	0xe79ef27ab89ffcafda77b2ff4e5f3f093a27bb3c685ea8e3602082f549b475de	2022-08-24 04:01:52+00
775	155574	0x98dfb8c596f0fe071c70fddb70d788aa3507e2d94dc400468f611b7a592dd430	2022-08-24 04:02:05+00
776	155575	0xb1ccbbb98848647632f1fe0d04d70736b9d36ec04b5761f9e855fc7cc029f0fc	2022-08-24 04:02:24+00
777	155576	0xb5e06e3ca1e4880b8b142d2171eaa331d5f3b974edc7995ff25cc5f65e132933	2022-08-24 04:03:01+00
778	155577	0xe7e7076a4424af371199d04076ddaddd4b1781d87172a05728df1b23aee92e43	2022-08-24 04:03:31+00
779	155578	0x5ab294948044085b6ea1ecb33d75e1363c3561337d88060b9231e033b49b8c96	2022-08-24 04:03:58+00
780	155579	0x72d3c76288305f06705d46716689f4c6d90cb825d97d7bcc6dc969b8fa0ebbd1	2022-08-24 04:04:53+00
781	155580	0xa932f1cf82589309c6e5e18d86f4e2de7889e82baca6e664f9b9ec48cce677a0	2022-08-24 04:05:35+00
782	155581	0x7442c95d38e5b9d3123bcd03274740c6f7f32e6531eefc1780da5cc57e6f4326	2022-08-24 04:05:52+00
783	155582	0x3485370553853d114202051861855d3b52dac3732186e5ce7d918117b4330f70	2022-08-24 04:06:04+00
784	155583	0x0e72a452dd03e775f07f58bb9d3d7c616779dd4dd697e1ebea7c2fb5d11c7e76	2022-08-24 04:06:19+00
785	155584	0xecc8f8b9f63403abba7abb0bd665750be74d85e12bf872289e89a2139f45fadd	2022-08-24 04:06:44+00
786	155585	0x43b9f8b353f1ad3f54991d3087345649bbe2d461ec8e92adcc20820eedca95c0	2022-08-24 04:08:10+00
787	155586	0x2a88481e08351756a6dd4eaed7083b05a63fe0dfd18f483c95cb26d71ac27189	2022-08-24 04:08:41+00
788	155587	0xd1c6de429fbbb8905aa4bb872c6c792c3b7e14e0e9053116a90d6e414094d320	2022-08-24 04:08:59+00
789	155588	0x66c1fa2853f9aaa463fda9bc0a378259244fb5eb295073950a695a94f134f0ed	2022-08-24 04:10:16+00
790	155589	0x64a9ca30dee0c3bf734b79ba2ba0f88570a9e25604d96bbd833adbe670453809	2022-08-24 04:10:36+00
791	155590	0xf3ca325428cfe7bc7e024d736364356029b515136e8b8129588d40e1dc9bf548	2022-08-24 04:11:15+00
792	155591	0xc1e826d3317a60e450100ae132c4cdf031ed78c9cad52cfa9cc381938c5382cb	2022-08-24 04:12:22+00
793	155592	0xb45281d66f53dee1a3a7a6404441b0f3c126ca389b5d6c296d12d09cb011f1b0	2022-08-24 04:13:19+00
794	155593	0x3732213ae864e52199775815040e34daa68fd47251c09a5489bb8daf2d4ab355	2022-08-24 04:14:28+00
795	155594	0x3f3f111381a4001ff5aa67e88c0b74fcfc85f800c5454c5fb8df3f06e069aa94	2022-08-24 04:15:03+00
796	155595	0x8753ccdf4b37f032bc501f1b355e9e1a97e6d50dd66bbca00b74207ee48179f6	2022-08-24 04:15:32+00
797	155596	0x045657e41d55f541dc654ec6659ccf0590763a8400e076f8681e31f82fd7a1de	2022-08-24 04:16:29+00
798	155597	0xec2382927340d3b9c462a12b1a0274ea37ac98fc3dbf6266aa24416e48a9bcfa	2022-08-24 04:16:29+00
799	155598	0x027d1249f9d0dab68db0b82145535462113abdf67dcef543ad3cfb51fe40d1bb	2022-08-24 04:16:32+00
800	155599	0x61828efbdaf422d9d63ecdbbd7323cb1ca57d99f269bdfb730eada52f1980905	2022-08-24 04:16:34+00
\.


--
-- Data for Name: enhanced_transaction; Type: TABLE DATA; Schema: vulcan2xarbitrum; Owner: user
--

COPY vulcan2xarbitrum.enhanced_transaction (hash, method_name, arg0, arg1, arg2, args) FROM stdin;
\.


--
-- Data for Name: job; Type: TABLE DATA; Schema: vulcan2xarbitrum; Owner: user
--

COPY vulcan2xarbitrum.job (id, name, last_block_id, status, extra_info) FROM stdin;
1	raw_log_0x4d196378e636d22766d6a9c6c6f4f32ad3ecb050_extractor	640	processing	\N
2	Arbitrum_Polling_Transformer	640	processing	\N
\.


--
-- Data for Name: transaction; Type: TABLE DATA; Schema: vulcan2xarbitrum; Owner: user
--

COPY vulcan2xarbitrum.transaction (id, hash, to_address, from_address, block_id, nonce, value, gas_limit, gas_price, data) FROM stdin;
\.


--
-- Name: chain_id_seq; Type: SEQUENCE SET; Schema: chains; Owner: user
--

SELECT pg_catalog.setval('chains.chain_id_seq', 2, true);


--
-- Name: balances_id_seq; Type: SEQUENCE SET; Schema: dschief; Owner: user
--

SELECT pg_catalog.setval('dschief.balances_id_seq', 1, false);


--
-- Name: delegate_lock_id_seq; Type: SEQUENCE SET; Schema: dschief; Owner: user
--

SELECT pg_catalog.setval('dschief.delegate_lock_id_seq', 1, false);


--
-- Name: lock_id_seq; Type: SEQUENCE SET; Schema: dschief; Owner: user
--

SELECT pg_catalog.setval('dschief.lock_id_seq', 1, false);


--
-- Name: vote_delegate_created_event_id_seq; Type: SEQUENCE SET; Schema: dschief; Owner: user
--

SELECT pg_catalog.setval('dschief.vote_delegate_created_event_id_seq', 1, false);


--
-- Name: vote_proxy_created_event_id_seq; Type: SEQUENCE SET; Schema: dschief; Owner: user
--

SELECT pg_catalog.setval('dschief.vote_proxy_created_event_id_seq', 1, false);


--
-- Name: mkr_joins_id_seq; Type: SEQUENCE SET; Schema: esm; Owner: user
--

SELECT pg_catalog.setval('esm.mkr_joins_id_seq', 1, false);


--
-- Name: mkr_joins_id_seq; Type: SEQUENCE SET; Schema: esmv2; Owner: user
--

SELECT pg_catalog.setval('esmv2.mkr_joins_id_seq', 1, false);


--
-- Name: logs_id_seq; Type: SEQUENCE SET; Schema: extracted; Owner: user
--

SELECT pg_catalog.setval('extracted.logs_id_seq', 3, true);


--
-- Name: logs_id_seq; Type: SEQUENCE SET; Schema: extractedarbitrum; Owner: user
--

SELECT pg_catalog.setval('extractedarbitrum.logs_id_seq', 1, false);


--
-- Name: balances_id_seq; Type: SEQUENCE SET; Schema: mkr; Owner: user
--

SELECT pg_catalog.setval('mkr.balances_id_seq', 1, false);


--
-- Name: transfer_event_id_seq; Type: SEQUENCE SET; Schema: mkr; Owner: user
--

SELECT pg_catalog.setval('mkr.transfer_event_id_seq', 1, false);


--
-- Name: poll_created_event_id_seq; Type: SEQUENCE SET; Schema: polling; Owner: user
--

SELECT pg_catalog.setval('polling.poll_created_event_id_seq', 1, false);


--
-- Name: poll_withdrawn_event_id_seq; Type: SEQUENCE SET; Schema: polling; Owner: user
--

SELECT pg_catalog.setval('polling.poll_withdrawn_event_id_seq', 1, false);


--
-- Name: voted_event_arbitrum_id_seq; Type: SEQUENCE SET; Schema: polling; Owner: user
--

SELECT pg_catalog.setval('polling.voted_event_arbitrum_id_seq', 1, false);


--
-- Name: voted_event_id_seq; Type: SEQUENCE SET; Schema: polling; Owner: user
--

SELECT pg_catalog.setval('polling.voted_event_id_seq', 1, false);


--
-- Name: block_id_seq; Type: SEQUENCE SET; Schema: vulcan2x; Owner: user
--

SELECT pg_catalog.setval('vulcan2x.block_id_seq', 520, true);


--
-- Name: job_id_seq; Type: SEQUENCE SET; Schema: vulcan2x; Owner: user
--

SELECT pg_catalog.setval('vulcan2x.job_id_seq', 16, true);


--
-- Name: transaction_id_seq; Type: SEQUENCE SET; Schema: vulcan2x; Owner: user
--

SELECT pg_catalog.setval('vulcan2x.transaction_id_seq', 3, true);


--
-- Name: block_id_seq; Type: SEQUENCE SET; Schema: vulcan2xarbitrum; Owner: user
--

SELECT pg_catalog.setval('vulcan2xarbitrum.block_id_seq', 800, true);


--
-- Name: job_id_seq; Type: SEQUENCE SET; Schema: vulcan2xarbitrum; Owner: user
--

SELECT pg_catalog.setval('vulcan2xarbitrum.job_id_seq', 2, true);


--
-- Name: transaction_id_seq; Type: SEQUENCE SET; Schema: vulcan2xarbitrum; Owner: user
--

SELECT pg_catalog.setval('vulcan2xarbitrum.transaction_id_seq', 1, false);


--
-- Name: chain chain_pkey; Type: CONSTRAINT; Schema: chains; Owner: user
--

ALTER TABLE ONLY chains.chain
    ADD CONSTRAINT chain_pkey PRIMARY KEY (id);


--
-- Name: chain unique_chain_name; Type: CONSTRAINT; Schema: chains; Owner: user
--

ALTER TABLE ONLY chains.chain
    ADD CONSTRAINT unique_chain_name UNIQUE (name);


--
-- Name: balances balances_pkey; Type: CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.balances
    ADD CONSTRAINT balances_pkey PRIMARY KEY (id);


--
-- Name: delegate_lock delegate_lock_log_index_tx_id_key; Type: CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.delegate_lock
    ADD CONSTRAINT delegate_lock_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: delegate_lock delegate_lock_pkey; Type: CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.delegate_lock
    ADD CONSTRAINT delegate_lock_pkey PRIMARY KEY (id);


--
-- Name: lock lock_log_index_tx_id_key; Type: CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.lock
    ADD CONSTRAINT lock_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: lock lock_pkey; Type: CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.lock
    ADD CONSTRAINT lock_pkey PRIMARY KEY (id);


--
-- Name: vote_delegate_created_event vote_delegate_created_event_log_index_tx_id_key; Type: CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.vote_delegate_created_event
    ADD CONSTRAINT vote_delegate_created_event_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: vote_delegate_created_event vote_delegate_created_event_pkey; Type: CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.vote_delegate_created_event
    ADD CONSTRAINT vote_delegate_created_event_pkey PRIMARY KEY (id);


--
-- Name: vote_proxy_created_event vote_proxy_created_event_log_index_tx_id_key; Type: CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.vote_proxy_created_event
    ADD CONSTRAINT vote_proxy_created_event_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: vote_proxy_created_event vote_proxy_created_event_pkey; Type: CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.vote_proxy_created_event
    ADD CONSTRAINT vote_proxy_created_event_pkey PRIMARY KEY (id);


--
-- Name: mkr_joins mkr_joins_log_index_tx_id_key; Type: CONSTRAINT; Schema: esm; Owner: user
--

ALTER TABLE ONLY esm.mkr_joins
    ADD CONSTRAINT mkr_joins_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: mkr_joins mkr_joins_pkey; Type: CONSTRAINT; Schema: esm; Owner: user
--

ALTER TABLE ONLY esm.mkr_joins
    ADD CONSTRAINT mkr_joins_pkey PRIMARY KEY (id);


--
-- Name: mkr_joins mkr_joins_log_index_tx_id_key; Type: CONSTRAINT; Schema: esmv2; Owner: user
--

ALTER TABLE ONLY esmv2.mkr_joins
    ADD CONSTRAINT mkr_joins_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: mkr_joins mkr_joins_pkey; Type: CONSTRAINT; Schema: esmv2; Owner: user
--

ALTER TABLE ONLY esmv2.mkr_joins
    ADD CONSTRAINT mkr_joins_pkey PRIMARY KEY (id);


--
-- Name: logs logs_log_index_tx_id_key; Type: CONSTRAINT; Schema: extracted; Owner: user
--

ALTER TABLE ONLY extracted.logs
    ADD CONSTRAINT logs_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: logs logs_pkey; Type: CONSTRAINT; Schema: extracted; Owner: user
--

ALTER TABLE ONLY extracted.logs
    ADD CONSTRAINT logs_pkey PRIMARY KEY (id);


--
-- Name: logs logs_log_index_tx_id_key; Type: CONSTRAINT; Schema: extractedarbitrum; Owner: user
--

ALTER TABLE ONLY extractedarbitrum.logs
    ADD CONSTRAINT logs_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: logs logs_pkey; Type: CONSTRAINT; Schema: extractedarbitrum; Owner: user
--

ALTER TABLE ONLY extractedarbitrum.logs
    ADD CONSTRAINT logs_pkey PRIMARY KEY (id);


--
-- Name: balances balances_pkey; Type: CONSTRAINT; Schema: mkr; Owner: user
--

ALTER TABLE ONLY mkr.balances
    ADD CONSTRAINT balances_pkey PRIMARY KEY (id);


--
-- Name: transfer_event transfer_event_log_index_tx_id_key; Type: CONSTRAINT; Schema: mkr; Owner: user
--

ALTER TABLE ONLY mkr.transfer_event
    ADD CONSTRAINT transfer_event_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: transfer_event transfer_event_pkey; Type: CONSTRAINT; Schema: mkr; Owner: user
--

ALTER TABLE ONLY mkr.transfer_event
    ADD CONSTRAINT transfer_event_pkey PRIMARY KEY (id);


--
-- Name: poll_created_event poll_created_event_log_index_tx_id_key; Type: CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.poll_created_event
    ADD CONSTRAINT poll_created_event_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: poll_created_event poll_created_event_pkey; Type: CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.poll_created_event
    ADD CONSTRAINT poll_created_event_pkey PRIMARY KEY (id);


--
-- Name: poll_withdrawn_event poll_withdrawn_event_log_index_tx_id_key; Type: CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.poll_withdrawn_event
    ADD CONSTRAINT poll_withdrawn_event_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: poll_withdrawn_event poll_withdrawn_event_pkey; Type: CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.poll_withdrawn_event
    ADD CONSTRAINT poll_withdrawn_event_pkey PRIMARY KEY (id);


--
-- Name: voted_event_arbitrum voted_event_arbitrum_log_index_tx_id_key; Type: CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.voted_event_arbitrum
    ADD CONSTRAINT voted_event_arbitrum_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: voted_event_arbitrum voted_event_arbitrum_pkey; Type: CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.voted_event_arbitrum
    ADD CONSTRAINT voted_event_arbitrum_pkey PRIMARY KEY (id);


--
-- Name: voted_event voted_event_log_index_tx_id_key; Type: CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.voted_event
    ADD CONSTRAINT voted_event_log_index_tx_id_key UNIQUE (log_index, tx_id);


--
-- Name: voted_event voted_event_pkey; Type: CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.voted_event
    ADD CONSTRAINT voted_event_pkey PRIMARY KEY (id);


--
-- Name: migrations_mkr migrations_mkr_name_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.migrations_mkr
    ADD CONSTRAINT migrations_mkr_name_key UNIQUE (name);


--
-- Name: migrations_mkr migrations_mkr_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.migrations_mkr
    ADD CONSTRAINT migrations_mkr_pkey PRIMARY KEY (id);


--
-- Name: migrations_vulcan2x_core migrations_vulcan2x_core_name_key; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.migrations_vulcan2x_core
    ADD CONSTRAINT migrations_vulcan2x_core_name_key UNIQUE (name);


--
-- Name: migrations_vulcan2x_core migrations_vulcan2x_core_pkey; Type: CONSTRAINT; Schema: public; Owner: user
--

ALTER TABLE ONLY public.migrations_vulcan2x_core
    ADD CONSTRAINT migrations_vulcan2x_core_pkey PRIMARY KEY (id);


--
-- Name: address address_address_key; Type: CONSTRAINT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.address
    ADD CONSTRAINT address_address_key UNIQUE (address);


--
-- Name: block block_pkey; Type: CONSTRAINT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.block
    ADD CONSTRAINT block_pkey PRIMARY KEY (id);


--
-- Name: enhanced_transaction enhanced_transaction_pkey; Type: CONSTRAINT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.enhanced_transaction
    ADD CONSTRAINT enhanced_transaction_pkey PRIMARY KEY (hash);


--
-- Name: job job_name_key; Type: CONSTRAINT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.job
    ADD CONSTRAINT job_name_key UNIQUE (name);


--
-- Name: job job_pkey; Type: CONSTRAINT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.job
    ADD CONSTRAINT job_pkey PRIMARY KEY (id);


--
-- Name: transaction transaction_pkey; Type: CONSTRAINT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.transaction
    ADD CONSTRAINT transaction_pkey PRIMARY KEY (id);


--
-- Name: transaction transaction_unique_hash; Type: CONSTRAINT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.transaction
    ADD CONSTRAINT transaction_unique_hash UNIQUE (hash);


--
-- Name: block unique_hash; Type: CONSTRAINT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.block
    ADD CONSTRAINT unique_hash UNIQUE (hash);


--
-- Name: address address_address_key; Type: CONSTRAINT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.address
    ADD CONSTRAINT address_address_key UNIQUE (address);


--
-- Name: block block_pkey; Type: CONSTRAINT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.block
    ADD CONSTRAINT block_pkey PRIMARY KEY (id);


--
-- Name: enhanced_transaction enhanced_transaction_pkey; Type: CONSTRAINT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.enhanced_transaction
    ADD CONSTRAINT enhanced_transaction_pkey PRIMARY KEY (hash);


--
-- Name: job job_name_key; Type: CONSTRAINT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.job
    ADD CONSTRAINT job_name_key UNIQUE (name);


--
-- Name: job job_pkey; Type: CONSTRAINT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.job
    ADD CONSTRAINT job_pkey PRIMARY KEY (id);


--
-- Name: transaction transaction_pkey; Type: CONSTRAINT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.transaction
    ADD CONSTRAINT transaction_pkey PRIMARY KEY (id);


--
-- Name: transaction transaction_unique_hash; Type: CONSTRAINT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.transaction
    ADD CONSTRAINT transaction_unique_hash UNIQUE (hash);


--
-- Name: block unique_hash; Type: CONSTRAINT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.block
    ADD CONSTRAINT unique_hash UNIQUE (hash);


--
-- Name: chain_id_index; Type: INDEX; Schema: chains; Owner: user
--

CREATE INDEX chain_id_index ON chains.chain USING btree (chain_id);


--
-- Name: chief_balance_address_index; Type: INDEX; Schema: dschief; Owner: user
--

CREATE INDEX chief_balance_address_index ON dschief.balances USING btree (address);


--
-- Name: delegate_lock_block_id_index; Type: INDEX; Schema: dschief; Owner: user
--

CREATE INDEX delegate_lock_block_id_index ON dschief.delegate_lock USING btree (block_id);


--
-- Name: dschief_lock_block_id_index; Type: INDEX; Schema: dschief; Owner: user
--

CREATE INDEX dschief_lock_block_id_index ON dschief.lock USING btree (block_id);


--
-- Name: vote_proxy_created_event_vote_proxy_idx; Type: INDEX; Schema: dschief; Owner: user
--

CREATE INDEX vote_proxy_created_event_vote_proxy_idx ON dschief.vote_proxy_created_event USING btree (vote_proxy);


--
-- Name: extracted_logs_address; Type: INDEX; Schema: extracted; Owner: user
--

CREATE INDEX extracted_logs_address ON extracted.logs USING btree (address);


--
-- Name: extracted_logs_block_id; Type: INDEX; Schema: extracted; Owner: user
--

CREATE INDEX extracted_logs_block_id ON extracted.logs USING btree (block_id);


--
-- Name: extractedarbitrum_logs_address; Type: INDEX; Schema: extractedarbitrum; Owner: user
--

CREATE INDEX extractedarbitrum_logs_address ON extractedarbitrum.logs USING btree (address);


--
-- Name: extractedarbitrum_logs_block_id; Type: INDEX; Schema: extractedarbitrum; Owner: user
--

CREATE INDEX extractedarbitrum_logs_block_id ON extractedarbitrum.logs USING btree (block_id);


--
-- Name: address_index; Type: INDEX; Schema: mkr; Owner: user
--

CREATE INDEX address_index ON mkr.balances USING btree (address);


--
-- Name: arbitrum_poll_id_index; Type: INDEX; Schema: polling; Owner: user
--

CREATE INDEX arbitrum_poll_id_index ON polling.voted_event_arbitrum USING btree (poll_id);


--
-- Name: poll_id_index; Type: INDEX; Schema: polling; Owner: user
--

CREATE INDEX poll_id_index ON polling.voted_event USING btree (poll_id);


--
-- Name: timestamp_index; Type: INDEX; Schema: vulcan2x; Owner: user
--

CREATE INDEX timestamp_index ON vulcan2x.block USING btree ("timestamp");


--
-- Name: vulcan2x_block_hash_index; Type: INDEX; Schema: vulcan2x; Owner: user
--

CREATE INDEX vulcan2x_block_hash_index ON vulcan2x.block USING btree (hash);


--
-- Name: vulcan2x_block_number_index; Type: INDEX; Schema: vulcan2x; Owner: user
--

CREATE INDEX vulcan2x_block_number_index ON vulcan2x.block USING btree (number);


--
-- Name: vulcan2x_job_name; Type: INDEX; Schema: vulcan2x; Owner: user
--

CREATE INDEX vulcan2x_job_name ON vulcan2x.job USING btree (name);


--
-- Name: vulcan2xarbitrum_block_hash_index; Type: INDEX; Schema: vulcan2xarbitrum; Owner: user
--

CREATE INDEX vulcan2xarbitrum_block_hash_index ON vulcan2xarbitrum.block USING btree (hash);


--
-- Name: vulcan2xarbitrum_block_number_index; Type: INDEX; Schema: vulcan2xarbitrum; Owner: user
--

CREATE INDEX vulcan2xarbitrum_block_number_index ON vulcan2xarbitrum.block USING btree (number);


--
-- Name: vulcan2xarbitrum_job_name; Type: INDEX; Schema: vulcan2xarbitrum; Owner: user
--

CREATE INDEX vulcan2xarbitrum_job_name ON vulcan2xarbitrum.job USING btree (name);


--
-- Name: vulcan2xarbitrum_timestamp_index; Type: INDEX; Schema: vulcan2xarbitrum; Owner: user
--

CREATE INDEX vulcan2xarbitrum_timestamp_index ON vulcan2xarbitrum.block USING btree ("timestamp");


--
-- Name: balances balances_block_id_fkey; Type: FK CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.balances
    ADD CONSTRAINT balances_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: balances balances_tx_id_fkey; Type: FK CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.balances
    ADD CONSTRAINT balances_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: delegate_lock delegate_lock_block_id_fkey; Type: FK CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.delegate_lock
    ADD CONSTRAINT delegate_lock_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: delegate_lock delegate_lock_tx_id_fkey; Type: FK CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.delegate_lock
    ADD CONSTRAINT delegate_lock_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: lock lock_block_id_fkey; Type: FK CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.lock
    ADD CONSTRAINT lock_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: lock lock_tx_id_fkey; Type: FK CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.lock
    ADD CONSTRAINT lock_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: vote_delegate_created_event vote_delegate_created_event_block_id_fkey; Type: FK CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.vote_delegate_created_event
    ADD CONSTRAINT vote_delegate_created_event_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: vote_delegate_created_event vote_delegate_created_event_tx_id_fkey; Type: FK CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.vote_delegate_created_event
    ADD CONSTRAINT vote_delegate_created_event_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: vote_proxy_created_event vote_proxy_created_event_block_id_fkey; Type: FK CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.vote_proxy_created_event
    ADD CONSTRAINT vote_proxy_created_event_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: vote_proxy_created_event vote_proxy_created_event_tx_id_fkey; Type: FK CONSTRAINT; Schema: dschief; Owner: user
--

ALTER TABLE ONLY dschief.vote_proxy_created_event
    ADD CONSTRAINT vote_proxy_created_event_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: mkr_joins mkr_joins_block_id_fkey; Type: FK CONSTRAINT; Schema: esm; Owner: user
--

ALTER TABLE ONLY esm.mkr_joins
    ADD CONSTRAINT mkr_joins_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: mkr_joins mkr_joins_tx_id_fkey; Type: FK CONSTRAINT; Schema: esm; Owner: user
--

ALTER TABLE ONLY esm.mkr_joins
    ADD CONSTRAINT mkr_joins_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: mkr_joins mkr_joins_block_id_fkey; Type: FK CONSTRAINT; Schema: esmv2; Owner: user
--

ALTER TABLE ONLY esmv2.mkr_joins
    ADD CONSTRAINT mkr_joins_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: mkr_joins mkr_joins_tx_id_fkey; Type: FK CONSTRAINT; Schema: esmv2; Owner: user
--

ALTER TABLE ONLY esmv2.mkr_joins
    ADD CONSTRAINT mkr_joins_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: logs logs_block_id_fkey; Type: FK CONSTRAINT; Schema: extracted; Owner: user
--

ALTER TABLE ONLY extracted.logs
    ADD CONSTRAINT logs_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: logs logs_tx_id_fkey; Type: FK CONSTRAINT; Schema: extracted; Owner: user
--

ALTER TABLE ONLY extracted.logs
    ADD CONSTRAINT logs_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: logs logs_block_id_fkey; Type: FK CONSTRAINT; Schema: extractedarbitrum; Owner: user
--

ALTER TABLE ONLY extractedarbitrum.logs
    ADD CONSTRAINT logs_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2xarbitrum.block(id) ON DELETE CASCADE;


--
-- Name: logs logs_tx_id_fkey; Type: FK CONSTRAINT; Schema: extractedarbitrum; Owner: user
--

ALTER TABLE ONLY extractedarbitrum.logs
    ADD CONSTRAINT logs_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2xarbitrum.transaction(id) ON DELETE CASCADE;


--
-- Name: balances balances_block_id_fkey; Type: FK CONSTRAINT; Schema: mkr; Owner: user
--

ALTER TABLE ONLY mkr.balances
    ADD CONSTRAINT balances_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: balances balances_tx_id_fkey; Type: FK CONSTRAINT; Schema: mkr; Owner: user
--

ALTER TABLE ONLY mkr.balances
    ADD CONSTRAINT balances_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: transfer_event transfer_event_block_id_fkey; Type: FK CONSTRAINT; Schema: mkr; Owner: user
--

ALTER TABLE ONLY mkr.transfer_event
    ADD CONSTRAINT transfer_event_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: transfer_event transfer_event_tx_id_fkey; Type: FK CONSTRAINT; Schema: mkr; Owner: user
--

ALTER TABLE ONLY mkr.transfer_event
    ADD CONSTRAINT transfer_event_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: poll_created_event poll_created_event_block_id_fkey; Type: FK CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.poll_created_event
    ADD CONSTRAINT poll_created_event_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: poll_created_event poll_created_event_tx_id_fkey; Type: FK CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.poll_created_event
    ADD CONSTRAINT poll_created_event_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: poll_withdrawn_event poll_withdrawn_event_block_id_fkey; Type: FK CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.poll_withdrawn_event
    ADD CONSTRAINT poll_withdrawn_event_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: poll_withdrawn_event poll_withdrawn_event_tx_id_fkey; Type: FK CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.poll_withdrawn_event
    ADD CONSTRAINT poll_withdrawn_event_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: voted_event_arbitrum voted_event_arbitrum_block_id_fkey; Type: FK CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.voted_event_arbitrum
    ADD CONSTRAINT voted_event_arbitrum_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2xarbitrum.block(id) ON DELETE CASCADE;


--
-- Name: voted_event_arbitrum voted_event_arbitrum_tx_id_fkey; Type: FK CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.voted_event_arbitrum
    ADD CONSTRAINT voted_event_arbitrum_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2xarbitrum.transaction(id) ON DELETE CASCADE;


--
-- Name: voted_event voted_event_block_id_fkey; Type: FK CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.voted_event
    ADD CONSTRAINT voted_event_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: voted_event voted_event_tx_id_fkey; Type: FK CONSTRAINT; Schema: polling; Owner: user
--

ALTER TABLE ONLY polling.voted_event
    ADD CONSTRAINT voted_event_tx_id_fkey FOREIGN KEY (tx_id) REFERENCES vulcan2x.transaction(id) ON DELETE CASCADE;


--
-- Name: transaction transaction_block_id_fkey; Type: FK CONSTRAINT; Schema: vulcan2x; Owner: user
--

ALTER TABLE ONLY vulcan2x.transaction
    ADD CONSTRAINT transaction_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2x.block(id) ON DELETE CASCADE;


--
-- Name: transaction transaction_block_id_fkey; Type: FK CONSTRAINT; Schema: vulcan2xarbitrum; Owner: user
--

ALTER TABLE ONLY vulcan2xarbitrum.transaction
    ADD CONSTRAINT transaction_block_id_fkey FOREIGN KEY (block_id) REFERENCES vulcan2xarbitrum.block(id) ON DELETE CASCADE;


--
-- Name: postgraphile_watch_ddl; Type: EVENT TRIGGER; Schema: -; Owner: user
--

CREATE EVENT TRIGGER postgraphile_watch_ddl ON ddl_command_end
         WHEN TAG IN ('ALTER AGGREGATE', 'ALTER DOMAIN', 'ALTER EXTENSION', 'ALTER FOREIGN TABLE', 'ALTER FUNCTION', 'ALTER POLICY', 'ALTER SCHEMA', 'ALTER TABLE', 'ALTER TYPE', 'ALTER VIEW', 'COMMENT', 'CREATE AGGREGATE', 'CREATE DOMAIN', 'CREATE EXTENSION', 'CREATE FOREIGN TABLE', 'CREATE FUNCTION', 'CREATE INDEX', 'CREATE POLICY', 'CREATE RULE', 'CREATE SCHEMA', 'CREATE TABLE', 'CREATE TABLE AS', 'CREATE VIEW', 'DROP AGGREGATE', 'DROP DOMAIN', 'DROP EXTENSION', 'DROP FOREIGN TABLE', 'DROP FUNCTION', 'DROP INDEX', 'DROP OWNED', 'DROP POLICY', 'DROP RULE', 'DROP SCHEMA', 'DROP TABLE', 'DROP TYPE', 'DROP VIEW', 'GRANT', 'REVOKE', 'SELECT INTO')
   EXECUTE PROCEDURE postgraphile_watch.notify_watchers_ddl();


ALTER EVENT TRIGGER postgraphile_watch_ddl OWNER TO "user";

--
-- Name: postgraphile_watch_drop; Type: EVENT TRIGGER; Schema: -; Owner: user
--

CREATE EVENT TRIGGER postgraphile_watch_drop ON sql_drop
   EXECUTE PROCEDURE postgraphile_watch.notify_watchers_drop();


ALTER EVENT TRIGGER postgraphile_watch_drop OWNER TO "user";

--
-- PostgreSQL database dump complete
--

