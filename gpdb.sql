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
0	create-migrations-table	07df1e838505a575c55d08e52e3b0d77955b5ad9	2023-05-03 22:23:00.722453
1	mkr-token-init	6bd4f885f95d28877debf029b81e1cc4a31de183	2023-05-03 22:23:00.729968
2	polling-init	55fa788d4f1e207fb8035f91b6b0d46e6811987d	2023-05-03 22:23:00.738697
3	polling-views	bf85462959f7a4fb98527547df9c7d2c7b2eefbd	2023-05-03 22:23:00.754517
4	dschief-init	e0ce34cbf37ac68a8e8c28a36c3fb5547834aef1	2023-05-03 22:23:00.75989
5	dschief-vote-proxies	2b2c103ab00b04b08abdde861b8613408c84e7b5	2023-05-03 22:23:00.768558
6	votes-with-dschiefs	3eaf466c8fef3d07da7416713e69a072426f2411	2023-05-03 22:23:00.776266
7	polling-unique-votes	f94587fdce58a186367a7754c8a373fb8ce359b9	2023-05-03 22:23:00.782253
8	optimize	32b1875a7b57c6322d358857a2279232ae0ee103	2023-05-03 22:23:00.786303
9	fix-polling-unique	cf3f30285ef810ceeb9849873fdbd3a544abe55f	2023-05-03 22:23:00.79026
10	fix-current-vote	51becc91cbdb8080bedf7068666109921cfcc77c	2023-05-03 22:23:00.793966
11	fix-total-mkr-weight	6499299b7f05586e8b4c76d157a8400d4d41d527	2023-05-03 22:23:00.797284
12	revert-optimize	653fdb7d29eeacea54628b9544b3fcf73cf0e6c5	2023-05-03 22:23:00.800892
13	revert-revert	17b9d21a1cf70aa05455125bc57a5611c0602070	2023-05-03 22:23:00.804557
14	fix-optimized-mkr-balance	a431b3692d220b4dfeed59bdb2bab20728664bc4	2023-05-03 22:23:00.808064
15	valid-votes-block-number	8b19449941da0edf23aa9d0ea3df372e625c85d2	2023-05-03 22:23:00.81139
16	esm-init	251eb54044a938c7498d5052142be7413158b620	2023-05-03 22:23:00.814988
17	esm-query	ab13b81c2700ade1dcea8a4ea1a875a8a8d65aef	2023-05-03 22:23:00.822057
18	timestamp-not-block-number	eda4eb0b00ce78c12c4da3f9fe400d2ee2c670b0	2023-05-03 22:23:00.826965
19	current-block-queries	43f65d8b2178fcb3c3d4b2a3ac64f046aff3d34e	2023-05-03 22:23:00.83287
20	remove-timestamp-return	14c3a852e4fe128d9b1edfd4399dd525eff4b0df	2023-05-03 22:23:00.83834
21	vote-option-id-type	7310b882c1775819ec1c1585e4c5d83abf5f99d3	2023-05-03 22:23:00.843207
22	current-vote-ranked-choice	94e2720ee609c046f9d4fbddb68d72038cf3cbad	2023-05-03 22:23:00.847753
23	optimize-hot-or-cold	2910ba5418e847c19be33e4df7f174f2928995be	2023-05-03 22:23:00.851381
24	optimize-total-mkr-weight-proxy-and-no	2b0fe2600ff6e2b22b5642bba43a129e68d2fa88	2023-05-03 22:23:00.855078
25	all-current-votes	a833d09836c08ab2badbabb120b382668131e889	2023-05-03 22:23:00.858992
26	fix-all-active-vote-proxies	e12d01f9f768c6b3e6739c06ed27b5116f8c6e67	2023-05-03 22:23:00.862734
27	fix-hot-cold-flip-in-026	dbcd0e62f6b1185e6ac6509ceb8ddf97a5f61b19	2023-05-03 22:23:00.867179
28	unique-voters-fix-for-ranked-choice	e7fd2498e6e91fe2d3169ca2b99b1df465befd86	2023-05-03 22:23:00.870968
29	store-balances	3dd612be9c6bb81e9fdbb5c71522a400727ae697	2023-05-03 22:23:00.874625
30	store-chief-balances	b5d202e6fd8c52e62b5edad64e820b10640699f8	2023-05-03 22:23:00.882459
31	faster-polling-queries	be05803c693c93bd58cdcab33690e7d0149be916	2023-05-03 22:23:00.890059
32	faster-polling-apis	a6445115270efb32f01d7491f3593482768e51c6	2023-05-03 22:23:00.900388
33	polling-fixes	582b1b7d7ae00ca4ac3ea78444efde2a19d28828	2023-05-03 22:23:00.90431
34	dschief-vote-delegates	a2cdc87bf4be7472ac772cf2028d6f796f3ba6aa	2023-05-03 22:23:00.911512
35	all-vote-delegates	e45e96e7373fd5e061060aaf86c5756be8e4b103	2023-05-03 22:23:00.918686
36	double-linked-proxy	f027e655ea32026d8b592477ff0c753a70737565	2023-05-03 22:23:00.923341
37	all-current-votes-array	1ec02a261e5268d2f601000a819ec390a5c6fe16	2023-05-03 22:23:00.929079
38	all-current-votes-with-blocktimestamp	871d79c4eb35524e16994442804b18825be977fb	2023-05-03 22:23:00.933418
39	poll-votes-by-address	fe422475f35e865f9a6a7981fa2760a6aba38020	2023-05-03 22:23:00.937585
40	buggy-mkr-weight	6b4abc8cd5e5cf4b940377716ef57ed9b09c950b	2023-05-03 22:23:00.941438
41	hot-cold-chief-balances	8e6081d83f0db2b8e9d14beb1123dc7198a67cb3	2023-05-03 22:23:00.946281
42	handle-vote-proxy-created-after-poll-ends	44e3902a9291e2867334db700e2b1eee785512bb	2023-05-03 22:23:00.950189
43	buggy-poll-votes-by-address	25fd2d9a826a053f063836e1142d4ff556f34c23	2023-05-03 22:23:00.953919
44	rewrite-poll-votes-by-address	4f4fb2700d82a427101fd3e0e2bc2c0eda90c796	2023-05-03 22:23:00.95757
45	unique_voter_improvement	a831d34e097bd155e868947e5a6ba6af91349b8c	2023-05-03 22:23:00.961637
46	mkr-locked-delegate	042974da667fcf6b8b5fd3b9e85dee26737e20bc	2023-05-03 22:23:00.965583
47	mkr-delegated-to	808eeb0d6aa0ccfc5ea46025eb3f41f58f6e7ace	2023-05-03 22:23:00.969876
48	mkr-locked-delegate-with-hash	f592a35a68e84cc07bea73dbcef2ca53f7f71dd1	2023-05-03 22:23:00.973716
49	polling-by-id	bef43083b7fdd7e09f3097ec698871c3ba88a550	2023-05-03 22:23:00.977714
50	esm-v2-init	71efa4fbfe551c617d1a686950afee2e97725bdd	2023-05-03 22:23:00.98189
51	esm-v2-query	5728974c0e67e30014b369298c4dc3a55862136b	2023-05-03 22:23:00.988772
52	mkr-locked-delegate-array	57b9c28ed782cb910aa5bbfc3d41b2ef3d17cb77	2023-05-03 22:23:00.99279
53	all-locks-summed	6d622f56eebcc52260ef0070ff7666a780354cb8	2023-05-03 22:23:00.997574
54	mkr-locked-delegate-array-totals	b0fef906b3077439a008f26379a4f6b7a98efeb1	2023-05-03 22:23:01.001661
55	manual-lock-fix	ccbbd33546296bf0ea3712ff2346ffcb6d70d8b2	2023-05-03 22:23:01.005649
56	manual-lock-fix-2	17435c58ebaad7034c084961298826c0a9e90b43	2023-05-03 22:23:01.009486
57	manual-lock-fix-3	74eec08f834994af46f8ed0cd74a14ce565d734c	2023-05-03 22:23:01.012892
58	delegate_locks	11a39de8bd6aa5478c4c3ec475b52f45ea74cf19	2023-05-03 22:23:01.016353
59	new-delegate-event-queries	b3290ebf53446ba3656e24873d5f908948bc2e9b	2023-05-03 22:23:01.023783
60	arbitrum-polling-voted-event	33f8abf397b011350bf0889be4588c465cc92883	2023-05-03 22:23:01.028494
61	arbitrum-all-current-votes	eaa34cb02a401199af7492706152fc64a170cc2d	2023-05-03 22:23:01.036874
62	votes-at-time-arbitrum-ts-hash	a4e51703425cd3ec4f59339447063215c90ef67e	2023-05-03 22:23:01.042416
63	updated-arbitrum-all-current-votes	27a187f4625aa058da51ffda971f1b7f86045dc6	2023-05-03 22:23:01.048286
64	updated-polling-votes-at-time	29eab737d1f05a0fb298253f5ac25ff41a2071dc	2023-05-03 22:23:01.053832
65	live-poll-count	df0d08f3545f9833dc63672cb064402f0a8867a0	2023-05-03 22:23:01.057877
66	all-delegates-sorted	6dbcdeadb811a80a507dda0283e1983e31dec67f	2023-05-03 22:23:01.061662
67	updated-live-poll-count	2048474874524b54b0123d366718ecf225f10624	2023-05-03 22:23:01.06616
68	delegation-metrics	8f6a7424245a427558e52313af00dd3f957c50ed	2023-05-03 22:23:01.071662
69	all-delegates-paginated-with-random	29d1940df53fdf28ce3e0ae3495edffa58704db9	2023-05-03 22:23:01.076457
70	total-mkr-delegated-to-group	08bba1d42f4d3f48f3917887b7e6412fcd519871	2023-05-03 22:23:01.08158
71	delegates-sorted-by-type	1614a345fef39a548ea00549b641ce8ed52a945a	2023-05-03 22:23:01.085058
\.


--
-- Data for Name: migrations_vulcan2x_core; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.migrations_vulcan2x_core (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	37f1979105c4bfba94329a8507ec41fddb9f29c1	2023-05-03 22:23:00.537417
1	vulcan2x	bded5b7bd4b47fde5effa59b95d12e4575212a6f	2023-05-03 22:23:00.546439
2	extract	f3b2668b094fc39f2323258442796adbd8ef9858	2023-05-03 22:23:00.56869
3	vulcan2x-indexes	5ee2f922590b7ac796f9ad1b69985c246dd52e48	2023-05-03 22:23:00.579915
4	vulcan2x-indexes-2	16c4f03e8a30ef7c5a8249a68fa8c6fe48a48a0c	2023-05-03 22:23:00.586963
5	vulcan2x-indexes-3	4dbb6a537ee7dfe229365ae8d5b04847deb9a1ae	2023-05-03 22:23:00.595078
6	vulcan2x-tx-new-columns	38cea6cc3f2ea509d3961cfa899bdc84f2b4056f	2023-05-03 22:23:00.601036
7	vulcan2x-address	04e43db73f9f553279a28377ef90893fc665b076	2023-05-03 22:23:00.606662
8	vulcan2x-enhanced-tx	2abaf0774aa31fffdb0e24a27b77203cd62d6d9e	2023-05-03 22:23:00.613527
9	api-init	ab00c5bcba931cfa02377e0747e2f8644f778a19	2023-05-03 22:23:00.619711
10	archiver-init	5c19daa71e146875c3435007894c49dc2d19121b	2023-05-03 22:23:00.6242
11	redo-jobs	f8408190950d4fb105b8995d220ae7ef034c8875	2023-05-03 22:23:00.633682
12	job-status	2f7ff24a3dfb809145f721fb27ece628b8058eb3	2023-05-03 22:23:00.642175
13	clear-control-tables	e0f1fd3e0afefc12ecaa0739aaedc95768316d3e	2023-05-03 22:23:00.653888
14	vulcan2xArbitrum	69f5299c5ae669083f12fcb45e40fe5a6d1c3c4b	2023-05-03 22:23:00.66041
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
\.


--
-- Data for Name: transaction; Type: TABLE DATA; Schema: vulcan2x; Owner: user
--

COPY vulcan2x.transaction (id, hash, to_address, from_address, block_id, nonce, value, gas_limit, gas_price, data) FROM stdin;
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
\.


--
-- Data for Name: transaction; Type: TABLE DATA; Schema: vulcan2xarbitrum; Owner: user
--

COPY vulcan2xarbitrum.transaction (id, hash, to_address, from_address, block_id, nonce, value, gas_limit, gas_price, data) FROM stdin;
\.


--
-- Name: chain_id_seq; Type: SEQUENCE SET; Schema: chains; Owner: user
--

SELECT pg_catalog.setval('chains.chain_id_seq', 1, false);


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

SELECT pg_catalog.setval('extracted.logs_id_seq', 1, false);


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

SELECT pg_catalog.setval('vulcan2x.block_id_seq', 1, false);


--
-- Name: job_id_seq; Type: SEQUENCE SET; Schema: vulcan2x; Owner: user
--

SELECT pg_catalog.setval('vulcan2x.job_id_seq', 1, false);


--
-- Name: transaction_id_seq; Type: SEQUENCE SET; Schema: vulcan2x; Owner: user
--

SELECT pg_catalog.setval('vulcan2x.transaction_id_seq', 1, false);


--
-- Name: block_id_seq; Type: SEQUENCE SET; Schema: vulcan2xarbitrum; Owner: user
--

SELECT pg_catalog.setval('vulcan2xarbitrum.block_id_seq', 1, false);


--
-- Name: job_id_seq; Type: SEQUENCE SET; Schema: vulcan2xarbitrum; Owner: user
--

SELECT pg_catalog.setval('vulcan2xarbitrum.job_id_seq', 1, false);


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

