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
-- Name: job_status; Type: TYPE; Schema: public; Owner: user
--

CREATE TYPE public.job_status AS ENUM (
    'processing',
    'stopped',
    'not-ready'
);


ALTER TYPE public.job_status OWNER TO "user";

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
-- Name: votes(integer, integer); Type: FUNCTION; Schema: polling; Owner: user
--

CREATE FUNCTION polling.votes(poll_id integer, block_id integer) RETURNS TABLE(voter character, option_id integer, option_id_raw character, amount numeric, chain_id integer, block_timestamp timestamp with time zone, hash character varying)
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
    	where vv.block_id <= votes.block_id
$$;


ALTER FUNCTION polling.votes(poll_id integer, block_id integer) OWNER TO "user";

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
    select id from vulcan2x.block where timestamp <= to_timestamp(unixtime)
    order by timestamp desc limit 1
  )) 
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
1	31337	arbitrumTestnet
2	31337	goerli
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
0	create-migrations-table	07df1e838505a575c55d08e52e3b0d77955b5ad9	2022-10-19 17:10:22.794333
1	mkr-token-init	6bd4f885f95d28877debf029b81e1cc4a31de183	2022-10-19 17:10:22.798991
2	polling-init	55fa788d4f1e207fb8035f91b6b0d46e6811987d	2022-10-19 17:10:22.803609
3	polling-views	bf85462959f7a4fb98527547df9c7d2c7b2eefbd	2022-10-19 17:10:22.814231
4	dschief-init	e0ce34cbf37ac68a8e8c28a36c3fb5547834aef1	2022-10-19 17:10:22.815816
5	dschief-vote-proxies	2b2c103ab00b04b08abdde861b8613408c84e7b5	2022-10-19 17:10:22.821046
6	votes-with-dschiefs	3eaf466c8fef3d07da7416713e69a072426f2411	2022-10-19 17:10:22.823673
7	polling-unique-votes	f94587fdce58a186367a7754c8a373fb8ce359b9	2022-10-19 17:10:22.825614
8	optimize	32b1875a7b57c6322d358857a2279232ae0ee103	2022-10-19 17:10:22.826299
9	fix-polling-unique	cf3f30285ef810ceeb9849873fdbd3a544abe55f	2022-10-19 17:10:22.826938
10	fix-current-vote	51becc91cbdb8080bedf7068666109921cfcc77c	2022-10-19 17:10:22.82752
11	fix-total-mkr-weight	6499299b7f05586e8b4c76d157a8400d4d41d527	2022-10-19 17:10:22.828341
12	revert-optimize	653fdb7d29eeacea54628b9544b3fcf73cf0e6c5	2022-10-19 17:10:22.828989
13	revert-revert	17b9d21a1cf70aa05455125bc57a5611c0602070	2022-10-19 17:10:22.82955
14	fix-optimized-mkr-balance	a431b3692d220b4dfeed59bdb2bab20728664bc4	2022-10-19 17:10:22.830122
15	valid-votes-block-number	8b19449941da0edf23aa9d0ea3df372e625c85d2	2022-10-19 17:10:22.830722
16	esm-init	251eb54044a938c7498d5052142be7413158b620	2022-10-19 17:10:22.831439
17	esm-query	ab13b81c2700ade1dcea8a4ea1a875a8a8d65aef	2022-10-19 17:10:22.835185
18	timestamp-not-block-number	eda4eb0b00ce78c12c4da3f9fe400d2ee2c670b0	2022-10-19 17:10:22.835809
19	current-block-queries	43f65d8b2178fcb3c3d4b2a3ac64f046aff3d34e	2022-10-19 17:10:22.837225
20	remove-timestamp-return	14c3a852e4fe128d9b1edfd4399dd525eff4b0df	2022-10-19 17:10:22.838509
21	vote-option-id-type	7310b882c1775819ec1c1585e4c5d83abf5f99d3	2022-10-19 17:10:22.8392
22	current-vote-ranked-choice	94e2720ee609c046f9d4fbddb68d72038cf3cbad	2022-10-19 17:10:22.840126
23	optimize-hot-or-cold	2910ba5418e847c19be33e4df7f174f2928995be	2022-10-19 17:10:22.840669
24	optimize-total-mkr-weight-proxy-and-no	2b0fe2600ff6e2b22b5642bba43a129e68d2fa88	2022-10-19 17:10:22.841215
25	all-current-votes	a833d09836c08ab2badbabb120b382668131e889	2022-10-19 17:10:22.841886
26	fix-all-active-vote-proxies	e12d01f9f768c6b3e6739c06ed27b5116f8c6e67	2022-10-19 17:10:22.842552
27	fix-hot-cold-flip-in-026	dbcd0e62f6b1185e6ac6509ceb8ddf97a5f61b19	2022-10-19 17:10:22.843359
28	unique-voters-fix-for-ranked-choice	e7fd2498e6e91fe2d3169ca2b99b1df465befd86	2022-10-19 17:10:22.844038
29	store-balances	3dd612be9c6bb81e9fdbb5c71522a400727ae697	2022-10-19 17:10:22.8446
30	store-chief-balances	b5d202e6fd8c52e62b5edad64e820b10640699f8	2022-10-19 17:10:22.847105
31	faster-polling-queries	be05803c693c93bd58cdcab33690e7d0149be916	2022-10-19 17:10:22.84949
32	faster-polling-apis	a6445115270efb32f01d7491f3593482768e51c6	2022-10-19 17:10:22.853536
33	polling-fixes	582b1b7d7ae00ca4ac3ea78444efde2a19d28828	2022-10-19 17:10:22.854374
34	dschief-vote-delegates	a2cdc87bf4be7472ac772cf2028d6f796f3ba6aa	2022-10-19 17:10:22.856275
35	all-vote-delegates	e45e96e7373fd5e061060aaf86c5756be8e4b103	2022-10-19 17:10:22.858758
36	double-linked-proxy	f027e655ea32026d8b592477ff0c753a70737565	2022-10-19 17:10:22.859414
37	all-current-votes-array	1ec02a261e5268d2f601000a819ec390a5c6fe16	2022-10-19 17:10:22.860058
38	all-current-votes-with-blocktimestamp	871d79c4eb35524e16994442804b18825be977fb	2022-10-19 17:10:22.860652
39	poll-votes-by-address	fe422475f35e865f9a6a7981fa2760a6aba38020	2022-10-19 17:10:22.861359
40	buggy-mkr-weight	6b4abc8cd5e5cf4b940377716ef57ed9b09c950b	2022-10-19 17:10:22.861927
41	hot-cold-chief-balances	8e6081d83f0db2b8e9d14beb1123dc7198a67cb3	2022-10-19 17:10:22.862797
42	handle-vote-proxy-created-after-poll-ends	44e3902a9291e2867334db700e2b1eee785512bb	2022-10-19 17:10:22.86344
43	buggy-poll-votes-by-address	25fd2d9a826a053f063836e1142d4ff556f34c23	2022-10-19 17:10:22.864274
44	rewrite-poll-votes-by-address	4f4fb2700d82a427101fd3e0e2bc2c0eda90c796	2022-10-19 17:10:22.864889
45	unique_voter_improvement	a831d34e097bd155e868947e5a6ba6af91349b8c	2022-10-19 17:10:22.865404
46	mkr-locked-delegate	042974da667fcf6b8b5fd3b9e85dee26737e20bc	2022-10-19 17:10:22.86598
47	mkr-delegated-to	808eeb0d6aa0ccfc5ea46025eb3f41f58f6e7ace	2022-10-19 17:10:22.866573
48	mkr-locked-delegate-with-hash	f592a35a68e84cc07bea73dbcef2ca53f7f71dd1	2022-10-19 17:10:22.867162
49	polling-by-id	bef43083b7fdd7e09f3097ec698871c3ba88a550	2022-10-19 17:10:22.867801
50	esm-v2-init	71efa4fbfe551c617d1a686950afee2e97725bdd	2022-10-19 17:10:22.868429
51	esm-v2-query	5728974c0e67e30014b369298c4dc3a55862136b	2022-10-19 17:10:22.871469
52	mkr-locked-delegate-array	57b9c28ed782cb910aa5bbfc3d41b2ef3d17cb77	2022-10-19 17:10:22.872216
53	all-locks-summed	6d622f56eebcc52260ef0070ff7666a780354cb8	2022-10-19 17:10:22.873087
54	mkr-locked-delegate-array-totals	b0fef906b3077439a008f26379a4f6b7a98efeb1	2022-10-19 17:10:22.873876
55	manual-lock-fix	ccbbd33546296bf0ea3712ff2346ffcb6d70d8b2	2022-10-19 17:10:22.874546
56	manual-lock-fix-2	17435c58ebaad7034c084961298826c0a9e90b43	2022-10-19 17:10:22.875495
57	manual-lock-fix-3	74eec08f834994af46f8ed0cd74a14ce565d734c	2022-10-19 17:10:22.876114
58	delegate_locks	11a39de8bd6aa5478c4c3ec475b52f45ea74cf19	2022-10-19 17:10:22.87681
59	new-delegate-event-queries	b3290ebf53446ba3656e24873d5f908948bc2e9b	2022-10-19 17:10:22.881229
60	arbitrum-polling-voted-event	33f8abf397b011350bf0889be4588c465cc92883	2022-10-19 17:10:22.882458
61	arbitrum-all-current-votes	eaa34cb02a401199af7492706152fc64a170cc2d	2022-10-19 17:10:22.886759
62	votes-at-time-arbitrum-ts-hash	a4e51703425cd3ec4f59339447063215c90ef67e	2022-10-19 17:10:22.888002
63	updated-arbitrum-all-current-votes	27a187f4625aa058da51ffda971f1b7f86045dc6	2022-10-19 17:10:22.889231
\.


--
-- Data for Name: migrations_vulcan2x_core; Type: TABLE DATA; Schema: public; Owner: user
--

COPY public.migrations_vulcan2x_core (id, name, hash, executed_at) FROM stdin;
0	create-migrations-table	37f1979105c4bfba94329a8507ec41fddb9f29c1	2022-10-19 17:10:22.69558
1	vulcan2x	bded5b7bd4b47fde5effa59b95d12e4575212a6f	2022-10-19 17:10:22.703539
2	extract	f3b2668b094fc39f2323258442796adbd8ef9858	2022-10-19 17:10:22.715506
3	vulcan2x-indexes	5ee2f922590b7ac796f9ad1b69985c246dd52e48	2022-10-19 17:10:22.719846
4	vulcan2x-indexes-2	16c4f03e8a30ef7c5a8249a68fa8c6fe48a48a0c	2022-10-19 17:10:22.721824
5	vulcan2x-indexes-3	4dbb6a537ee7dfe229365ae8d5b04847deb9a1ae	2022-10-19 17:10:22.723775
6	vulcan2x-tx-new-columns	38cea6cc3f2ea509d3961cfa899bdc84f2b4056f	2022-10-19 17:10:22.726319
7	vulcan2x-address	04e43db73f9f553279a28377ef90893fc665b076	2022-10-19 17:10:22.727752
8	vulcan2x-enhanced-tx	2abaf0774aa31fffdb0e24a27b77203cd62d6d9e	2022-10-19 17:10:22.729378
9	api-init	ab00c5bcba931cfa02377e0747e2f8644f778a19	2022-10-19 17:10:22.731444
10	archiver-init	5c19daa71e146875c3435007894c49dc2d19121b	2022-10-19 17:10:22.731975
11	redo-jobs	f8408190950d4fb105b8995d220ae7ef034c8875	2022-10-19 17:10:22.737115
12	job-status	2f7ff24a3dfb809145f721fb27ece628b8058eb3	2022-10-19 17:10:22.739831
13	clear-control-tables	e0f1fd3e0afefc12ecaa0739aaedc95768316d3e	2022-10-19 17:10:22.745538
14	vulcan2xArbitrum	69f5299c5ae669083f12fcb45e40fe5a6d1c3c4b	2022-10-19 17:10:22.747483
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
1	7792488	0xc987c71ea220df62649cfa2e559636a5e8f0376eef0d8d00d37e5fda204dc618	2022-10-18 18:52:48+00
2	7792489	0x4ed371c40e41034934d5f930f7b0e35d8557bf5215d17e099e429ebd2471235e	2022-10-18 18:53:00+00
3	7792490	0x1ef9c690bb87e16d649f602d7ce654b86e8953261459a6dab2b8e3da10a3eece	2022-10-18 18:53:24+00
4	7792491	0x6f8c963ece5fd2803deaa6d48dc1fdcecacba1885eac64789b627780ca948ae8	2022-10-18 18:53:36+00
5	7792492	0xcccca51303fa1d1027b58f265c708138e9e99c19325c91e3fa07a7cec2acd22e	2022-10-18 18:53:48+00
6	7792493	0xb032ccfadda093939d44c936715bbde6338996ae8f70c1df2b54330365c0b690	2022-10-18 18:54:00+00
7	7792494	0x172b1060b495e12d334a50daf92067f3eec064034bc73e5b41860d7dd94581d4	2022-10-18 18:54:12+00
8	7792495	0x42274bc222c437af40d82bfed5f79f6a8a0ab2ef7c6ece2ed988afc9e0929387	2022-10-18 18:54:24+00
9	7792496	0xa8fbd5074f7740cfd98d9e05ffaae7f312a04136b8e9f82c8b08880599287fe6	2022-10-18 18:54:36+00
10	7792497	0x31f352ce1649fd8c3bb8acac2046980569cb81f7fa121bf91795ee2888d017d4	2022-10-18 18:54:48+00
11	7792498	0x80b36e7b2d25593ce7fd041b86e7260664c4d9959350fd4f59e18954e9779626	2022-10-18 18:55:00+00
12	7792499	0x82291391a1bbc7bbb8e385b23b6e1bcdd39ebab95fb06a83d3ea3cf8626d51f7	2022-10-18 18:55:12+00
13	7792500	0x55023d6a8d8be784db87dad9cc789a885e0fdfcfd25b4227595ce19fd99234d7	2022-10-18 18:55:24+00
14	7792501	0xdf05425a1ffc79ad4abed523ca50a61252361ea702ddc4fef4b490fb989c65fe	2022-10-18 18:55:48+00
15	7792502	0x7d87a04257b3819d33e8728f4476780330b436eb557a16b7067862ae294a8f75	2022-10-18 18:56:00+00
16	7792503	0xf744e3e3a269b2ee205dcfd25777b2865f1347f9092f6b2ff5c6332893416159	2022-10-18 18:56:24+00
17	7792504	0x22651156a823638edc933049b4bbceaee34b75423e73aacb095fedbccb3de667	2022-10-18 18:57:00+00
18	7792505	0x8d8815b1b1b1437db1466ca0b4f25976314107f583f2aedbb6397d7aa98b3fc1	2022-10-18 18:57:12+00
19	7792506	0x9d80fab71050426bcde6ea1b641fd440138e2df1c52d17d712b44f4ae1c5e69e	2022-10-18 18:57:24+00
20	7792507	0xa0c9f1659c7a151a4414791fe1d8e5a5e9cd62ebafe8ad280b0713c579b6c020	2022-10-18 18:57:36+00
21	7792508	0xbeed75f37442b8df185f858ce90fe882fe8f31deff9da41821e124e8a758ff7c	2022-10-18 18:57:48+00
22	7792509	0x0a91be4cf7180605a4f995ed5078ff2452594422e747bbded98938de64325661	2022-10-18 18:58:00+00
23	7792510	0xe4eeedb2fa8c2409290489c33f69bb4f075960f26a0e417c348aefc571af88d3	2022-10-18 18:58:12+00
24	7792511	0x7be4fc51d23d6e3ac96805dadcd4de1f2136fed8d891c5a03705542eb0cc86db	2022-10-18 18:58:36+00
25	7792512	0xa558ba077c33a90a3806ee44592079d7530cf0f77eeac424e428e99181ba833f	2022-10-18 18:58:48+00
26	7792513	0xbc5d713703b6e8fb73884268d87e96549616acb18c510361ca61b798e76d2193	2022-10-18 18:59:00+00
27	7792514	0x7fab26d818a42e7e3d1ddae067b272aa4b7ca8b6c71cca69411ed16d2d1a74b7	2022-10-18 18:59:12+00
28	7792515	0x1b4fff31a024c00cae08a6c9a027e6e525b475bcd4d07b50f6a714e368f17708	2022-10-18 18:59:36+00
29	7792516	0x00ff5cb60f5a90c3b33c9e050a21a777664f735f29acb58be626158fbdc08d13	2022-10-18 19:00:00+00
30	7792517	0xb47dcf14350ae616e4396822b97796cc102d331ef7f63e7810914b4f79c41e1a	2022-10-18 19:00:24+00
31	7792518	0xb9eb4fcbcb9f31427c1223888618e2a6d02521b897672476f8d80c480b2b7b41	2022-10-18 19:00:48+00
32	7792519	0x05db2512da1b461a4c546041ebc4eacef1c1187cc8d800b97f5dc1ad58da4476	2022-10-18 19:01:00+00
33	7792520	0x3b95735e0aae25af128123688d7d4c6e927d5714766c7699ddcad515250d6bea	2022-10-18 19:01:24+00
34	7792521	0xb7145e7e32f31308fc2c3bbe894538e7f78b4e9ca8cfa78ca70399d39ad02b75	2022-10-18 19:01:36+00
35	7792522	0x0e437a1acdbd345b45a6bf770fcda8771608112621e54da593c464c80f35f23b	2022-10-18 19:01:48+00
36	7792523	0xec1118a236f0d09318764e6e6f3f9dacdb8b57173e6cb1d9a9858883b8700d7c	2022-10-18 19:02:00+00
37	7792524	0xf63caa80cbce0fd554346b6a1473e82f8629932bd8dd43a4de664ee6c2911d50	2022-10-18 19:02:12+00
38	7792525	0x6137193cbcd15974410da7d97de099b2cc8b7b148011d31d8773310d3f239061	2022-10-18 19:02:24+00
39	7792526	0xf294b8a1178026e40457837736e91719323c8ffe502f114f69ee29175eaf082b	2022-10-18 19:02:36+00
40	7792527	0xc52ea8fb4f5038edca8bde16d565fa87596efb978e13374acf9199da880c9aae	2022-10-18 19:02:48+00
41	7792528	0x3c67d59976f80da260fc6de8fc8d0dacccd6e7470b1fd82b94145c0b770579f6	2022-10-18 19:03:00+00
42	7792529	0xadb1e8319a3088b14ea3ab20b0d9c4ee9350a672efa0ef1b6adac483a6539b0d	2022-10-18 19:03:12+00
43	7792530	0x062933fe12f19507fa3ffa6e5f11da4c7a963e8b38ad382f3e1987f8f52ba71d	2022-10-18 19:03:24+00
44	7792531	0x69d8e10e412fbb15ae94b42a4eef8ba475fa0920d1ccdf5b7bfb5b2be86752a9	2022-10-18 19:03:36+00
45	7792532	0x65327eef653e37c6e64f271d30a405dd3da3bac6cae706033d86353b3aa6444d	2022-10-18 19:03:48+00
46	7792533	0x2f1aaeadc21b4ca4868e9a30803f9f7ad3167610f932a8f82d3967f4bc9637d2	2022-10-18 19:04:00+00
47	7792534	0xad7f1821866fbf44a7f945ee4100190964ba4852a9e4a186b0c4a1d0b4a583e1	2022-10-18 19:04:12+00
48	7792535	0xc3aeed5a54adf432bdfea6dd10778ba8f31cc2fbd1693f1d7b1b1214f85be5a1	2022-10-18 19:04:36+00
49	7792536	0x6abad47092a2879e2842620e7a92758936fe6b420a0dfbe5fa597ea48c1d7069	2022-10-18 19:05:00+00
50	7792537	0xe3885fd5b0341535a8886a869d8c258ba18b7541fbfbcb0265b8f82b3fcd5a62	2022-10-18 19:05:24+00
51	7792538	0x2c7e1ee5d2dbefc954ee468bbd6d53a3965000a1484edc5a42bccf98d7e91dcd	2022-10-18 19:05:36+00
52	7792539	0xc893ec1cb2a76615f0b8bf0f9794c24660b8e6ad293ac5903e7e222086b2f37e	2022-10-18 19:05:48+00
53	7792540	0xd892202c001efd51b53d61fcf3aff375edc5458239cb0f72e19fecd764959608	2022-10-18 19:06:00+00
54	7792541	0x22cb35ba7a7c087e2d5f1360c57b3e27374f1e2cde9d08cd798a8b9d820a1728	2022-10-18 19:06:12+00
55	7792542	0x01883fa76d4f25e62de01701f225fb87881cdfcc78ad40c9cb6730beb2d1bc7d	2022-10-18 19:06:24+00
56	7792543	0x868e1f65a496f3d218494cc6939c811a461533fb5cfdef0a9a311d0c2522d23d	2022-10-18 19:06:36+00
57	7792544	0x200616a14cf39c118a512f5b537c3ab7432c3ead754373681f51edabe64f5c62	2022-10-18 19:06:48+00
58	7792545	0xa453963549c418ec0b13a922134ea9b265577fcb1d461e6c5b22a1fc81225d93	2022-10-18 19:07:00+00
59	7792546	0x15cd937d49d3482a981fc5be76c7552cdb8e33c9f7f431c6a6ecb8857d449fb0	2022-10-18 19:07:12+00
60	7792547	0xaf5fe0244ac2b95d155819c2fa34fd5bae8b4ad2df98991a51689fa03db6c33e	2022-10-18 19:07:24+00
61	7792548	0x2be06df69c296ddccd02f7e071e0cd8c075902b3ce4718920222a92f8641dbda	2022-10-18 19:07:36+00
62	7792549	0xffd29e1ebd162affd3e1466bda2bdfb753b0e3d4fdf54e2d08ac9041ee7a86f8	2022-10-18 19:07:48+00
63	7792550	0xfa85324c8b4438df05187481bd4fe19d680564f35c1895c85ff88dfcb7c4ccd8	2022-10-18 19:08:24+00
64	7792551	0x2ca9f2119e86a3e95e4fa98330f8b11a0ba557c9940abec0921c1bff9095e205	2022-10-18 19:08:48+00
65	7792552	0xea8785449b3573dde4ca816af202eecb48b74a4c17c0e8e1c0926ed98398f85f	2022-10-18 19:09:00+00
66	7792553	0x19a3ceb11c720693aa7c172255621df5e8608b80e0b95d53cd9aab1e786812b0	2022-10-18 19:09:12+00
67	7792554	0xd5fc73c9e0711014a8985db3f8120e7c56e59eea00c0455710ad1ec971d0b608	2022-10-18 19:09:24+00
68	7792555	0x3168c78111ff6523e8b37dfcacaa892db2167f7dea382450bfee49ad64a8c889	2022-10-18 19:09:48+00
69	7792556	0x117110e283dba61710ac05c7f5a1f03a3d51f1f88ecfa94193d8b2ba7b213dc1	2022-10-18 19:10:12+00
70	7792557	0xe82cdd9500653eadcdc76129dfbac0f76eb0ad61054801a5d2e4d6bdd90180d5	2022-10-18 19:10:24+00
71	7792558	0x2e32bb5bb85c29aa04fa998c0959f26ab50c3f1028c30b5cb96daf4daf3632ad	2022-10-18 19:10:36+00
72	7792559	0x27afe0d2fafea6dc37fa78db6cc7998bbeb4f90d4a8dd74cf9d75094a224bfa2	2022-10-18 19:10:48+00
73	7792560	0x9342ea48a3d4e2d3e2ddcd84d5de0b8a0cfe8aa40d64d1c8cf1c74865423a812	2022-10-18 19:11:00+00
74	7792561	0x65c4fb64bd6a3f0a04e7efeb6f4d34b38fcc4b5c388b7439f18dd273dbf29e86	2022-10-18 19:11:12+00
75	7792562	0xce03274ecd901d0b6e6d9105a82960f22670fe2a85b31dcef0a30a165d4dd595	2022-10-18 19:11:24+00
76	7792563	0x33cc72c5e4e0701414d25691c86c417fcc88dcb23f4ff8dbbfa2c033445bce71	2022-10-18 19:11:36+00
77	7792564	0x6791fc38f1661690f81b4f99818843352ee732d59bdf5576f375824c7ed9ef32	2022-10-18 19:11:48+00
78	7792565	0x8d56cd3f6af1759a4f3e09e225c444705e3a172f54da704fa6572eb2bab5a109	2022-10-18 19:12:12+00
79	7792566	0x4a5c31f0af435505bec3978118ed0c4a5388db010e76f390197ad66c8fee4bd4	2022-10-18 19:12:24+00
80	7792567	0x502d47d74bb4344b3c2ac1b492acc569f124276906c3dd079b53179d0bcf2f34	2022-10-18 19:12:36+00
81	7792568	0x6a5366433bdb2c6ea305b0af68c2cc8e43d7515e70d1631d9e557c862031edc8	2022-10-18 19:12:48+00
82	7792569	0xdc5f39f70f13931ebba56955451cc77a1d5327ee059209983e3c6004a290887d	2022-10-18 19:13:00+00
83	7792570	0x7d1abbf97242863e3cc547ed7292ac011d860cfa3f4463f5a16c606703269940	2022-10-18 19:13:24+00
84	7792571	0x6e31030e2fece75ee385c1590a62580264ae4e17cd8fcfc61b745bf21da7ab7e	2022-10-18 19:13:36+00
85	7792572	0x457fb96052264340361864369b4a0eff4e0311c40e75d90537497732a4d82697	2022-10-18 19:13:48+00
86	7792573	0xaebff68a9bd971093f5e50bff2ddd5afd71c3e61f077b3f76a64d13714fbebec	2022-10-18 19:14:00+00
87	7792574	0x7966b5d381ad48c143604606726d3f0608cb35a744bb79b3b829907e19c46d60	2022-10-18 19:14:24+00
88	7792575	0x6f96bd7790c362eab1734356f39801a11972e9ec0c7bc33a031e137e3025c364	2022-10-18 19:14:36+00
89	7792576	0x09b8ed999f15a837b92dc61c7919ba3e4d708c5542e92656ffddef417d993364	2022-10-18 19:14:48+00
90	7792577	0xd6cdbb6a77af19ca9aec810a53e0638d2b262093a49734ca5e12a97af12c10d4	2022-10-18 19:15:12+00
91	7792578	0xfc998180c95eb5ed63fe1180d28c70c42a87ae5ac6d1bf78d3b3052cdd31bc9a	2022-10-18 19:15:24+00
92	7792579	0xa80423a893a70aa2d3030699c164e400b8c666f574e6780cab991f282c1b345e	2022-10-18 19:15:36+00
93	7792580	0x62a480faaa87c6aa00df25d81eb0e7b26b569f4e3f46898091da6ff7a1b377a3	2022-10-18 19:15:48+00
94	7792581	0xb6f100b8e062d6542d440f69a9fddf6f64a6a2e5c838e433302ba7fc2572bc33	2022-10-18 19:16:00+00
95	7792582	0xd2580613ce060e0011543bca61b196a135a9ea678c2a5a35184e20f245be8120	2022-10-18 19:16:12+00
96	7792583	0xf597fb8505ecc4542ec437237764bceb402ce9a5536a9a57f44868d6e5e66e95	2022-10-18 19:16:36+00
97	7792584	0xc93691fced4b9abcce6ee03fa3b123271a7f03ba0b1c1794fcb1585af2ac161d	2022-10-18 19:16:48+00
98	7792585	0xead43c123fe7b49d3b4253eb0c8ba747ef627bccf4903ed56aa1a981cb2f2b5c	2022-10-18 19:17:00+00
99	7792586	0x1466cf5a8af1bdd6dcb79b883181a72ff435a859f7e9f2f1ff58f6317f15e620	2022-10-18 19:17:24+00
100	7792587	0x1b2ac77ddd93641a659e7bf82e092b0094f5a6065076b92e23c2d2145436d3de	2022-10-18 19:17:36+00
101	7792588	0x736e80a575ad11bd6c9b4edd7b86305e5751d4973f8573d6fcdcdb58b6568582	2022-10-18 19:17:48+00
102	7792589	0x6dc7b039f98910d6921d1f751b1cc2c58803416d29b1e7da7612605798efc12d	2022-10-18 19:18:00+00
103	7792590	0xdc7419bfcb68e1f5c029d4d2b1af71efd878287bb01e002248c7aa144e0a21be	2022-10-18 19:18:12+00
104	7792591	0xaf896d8eff3e9c1d2a29c0d3f986f06e24d8d3cef2bfe2d2cbae15e126681737	2022-10-18 19:18:24+00
105	7792592	0x9920ad8915e26b42eb523b3d3d2bf1548d6f54ebbf5213a00dfe13c613221706	2022-10-18 19:18:36+00
106	7792593	0x3214a016596c5da3dbbb14e490750d5166e4442c88374a27bda63320faa4ed18	2022-10-18 19:18:48+00
107	7792594	0x3c19e5db5bc0e0793140d863051850c7ff6fd66306b2813c94f54a61d6f00e47	2022-10-18 19:19:00+00
108	7792595	0xc1753f2555f9605bc13f098b17faf0ab2be299c41befbcd884a4eeaf750e3b72	2022-10-18 19:19:12+00
109	7792596	0x019d35a498b4c1f8417c064626552924f70a6c9fa3d25edac98bef309cd3ae16	2022-10-18 19:19:24+00
110	7792597	0x57966eccb59e2197151f82aeaded90869e3ff4c791989cfecb08dbc6c6dbfd5a	2022-10-18 19:19:36+00
111	7792598	0x8dcd81b18464e7a57f4d3006fa6f17f00cdfc671b7ccc802b2ba744881ea1d17	2022-10-18 19:19:48+00
112	7792599	0x570e90061c9ab4baa974106e0d6f1ca606fbde05e1269320f8446bb80cd156c2	2022-10-18 19:20:00+00
113	7792600	0x643c32da92ebc6284b8f87d5e6b54e8f7afd59a667351b1639c8bab8b48c1ebb	2022-10-18 19:20:12+00
114	7792601	0xc23701ea7840158b3ce6b1b3b4e76c65436e32cd5746defdd3882b14fb1245f8	2022-10-18 19:20:24+00
115	7792602	0xe95c67b5c5770dadf443bc6bdcbafc772b88536da3feb1491f468784f8d14e62	2022-10-18 19:20:36+00
116	7792603	0xfe7338f3586b6d5c6c080b6399ea933f4b086afaefc08338f63deb74abb040b4	2022-10-18 19:20:48+00
117	7792604	0x7226782fc4273ce9f703b3bcbf05bf18dc9718c8475910937008ae6104de6183	2022-10-18 19:21:00+00
118	7792605	0x38695987a19a9f294fd957f2bb45124adaa1012ef6b5196dbde3b8135dd24c0c	2022-10-18 19:21:24+00
119	7792606	0xa9c8fab688f92252f4a369d30dbd73887cfe1aa2bd142e7e68734e8d2ce2f20a	2022-10-18 19:21:36+00
120	7792607	0x4cf7eff1c2db74229f081e3c6d0562053b0ca10a090a93eb72f2d56149a1ac0c	2022-10-18 19:21:48+00
121	7792608	0x96af7e4f7d2019715a94d7181fa065cf03432bd2fd03518f8a346295ac871b98	2022-10-18 19:22:00+00
122	7792609	0x8f8a23caac5d5242d89a3afa851d00db80ed1b23800e2224eebb6ab37d3163d4	2022-10-18 19:22:12+00
123	7792610	0xd56bfbbba48847976e8f1f6a236803b80a92fe97178e74f1259c09e6bd452396	2022-10-18 19:22:24+00
124	7792611	0xd9a240ed2d5d789f04a03430700b7734464ed7caf63ccca8a7d1aaf9579b5b5d	2022-10-18 19:22:36+00
125	7792612	0x26780c1c45703bc13520006f76aca4654f09f47d31fb5b292dc226596f475296	2022-10-18 19:22:48+00
126	7792613	0x682b8a519aa2c8b610c1e6bc2db426397c6d009008d4969b0bc52a30e7b7e0c3	2022-10-18 19:23:00+00
127	7792614	0xd53938fa886fd9bcd61b73f9abcb2f9999b91d226fae3a311c3bf5800c198c46	2022-10-18 19:23:12+00
128	7792615	0x9b0ef070e7a2bac78dee360e2f9e315e6303c4e49a87cd2d1bbf706b772e65b3	2022-10-18 19:23:24+00
129	7792616	0x1489ca976e0ffd4e4caa59920be8f84f066ea7416537e0304800328b1a954e1f	2022-10-18 19:23:36+00
130	7792617	0x23146effb771d634eb3278297c6d0e4f524ee61b163a51808e55008e04d87f58	2022-10-18 19:23:48+00
131	7792618	0x994c7748e582ec53bb8b0c02548fc770bd538a9060f1a6a6705592a718d4901b	2022-10-18 19:24:12+00
132	7792619	0x24b97ad78b01fb9f02bfcd1efdbcf96fbec76857883e4ffb8f7b578311db37f4	2022-10-18 19:24:24+00
133	7792620	0x918bc3230599f2b0a36eaebb74d073f7b11848326944666bea2449296d661f11	2022-10-18 19:24:36+00
134	7792621	0x68820c6f1062609c5a15e021035644648c204dcdcab49d8c88b67eba152b6d39	2022-10-18 19:25:00+00
135	7792622	0x66257c9f10d56bc7184c6516addbd31441cb6adc3f17c6599d2fd6d45e52733a	2022-10-18 19:25:12+00
136	7792623	0x607a3c52fd201c3ec0f9235bef1653bce8c871d88285c600f5d1f8d15539df61	2022-10-18 19:25:24+00
137	7792624	0xaf45bf0499eafb5ada18e8813a58882e7c891b469e4e58d4a6ef30db56b53c75	2022-10-18 19:25:48+00
138	7792625	0x2b967c709a73cba201045b4a75bd96d5e5edc681e97537e3dc94bc965e5e3060	2022-10-18 19:26:12+00
139	7792626	0x1bfa287bb891aa8b1b8222db364fd56c9fed00ef84f3409e5a30e69a1b13109e	2022-10-18 19:26:24+00
140	7792627	0xc30b82bb729a72055cdc0e2e8c6f3ddd24eecc05738b16dcea3bfc974a6abdf8	2022-10-18 19:26:36+00
141	7792628	0x8e7bb9716aed5ed07b451f381eb11b2cebc7b1f13b9840f6b4ac0472e58d8d2c	2022-10-18 19:26:48+00
142	7792629	0xd59928a8f8073e5b509ff0466d05bad2bbc907bed4fcb35b331324c80c26372c	2022-10-18 19:27:12+00
143	7792630	0x28da6a6c8e322203cc7d481842ace9072489318a0171094cd061dd0f4dd2218d	2022-10-18 19:27:24+00
144	7792631	0xf283a6e2a5ff5ca911c8deaa29a80ad1c7713fe9a42006a60fe0b10b78818ace	2022-10-18 19:28:00+00
145	7792632	0xc1daf0ec88c8398c3aed82b08800104712f005a279588f3c98247372cc5f5b19	2022-10-18 19:28:12+00
146	7792633	0x83fb1ddefcc05dfabde0276c303b52f56819d015f2c3d8ecbc46006e12186565	2022-10-18 19:28:36+00
147	7792634	0x2b8b34ebb5c4c2eb5fab9f7b226cd6933a7c57f3a76dd919adaaabe37501e148	2022-10-18 19:28:48+00
148	7792635	0xbdaaad80640b7895e7f3db6db6481aef326feeac05b3e02d650828dbf2f18f44	2022-10-18 19:29:00+00
149	7792636	0x5bbf13ded148fa364fc9ad08668d8a38a0dd5d412e94970e1ac8dc9b16e5e2d2	2022-10-18 19:29:24+00
150	7792637	0x81c710e71b6a1ce4d4599424a8373d2b7a19499a32aa4fafd4e292ecf6a15529	2022-10-18 19:29:36+00
151	7792638	0xed601d1afbd492a338aca68957134380aaf765fa28188370d9c85541635d1b1e	2022-10-18 19:29:48+00
152	7792639	0x8c6f269e86be9a171198880370e7a56e234008bac31204c62aa2a0e3bd0071fd	2022-10-18 19:30:00+00
153	7792640	0x682ecc5718b6eea59011004260aa7425c30f036f5f15a3b7b5309ee4f25bc06a	2022-10-18 19:30:24+00
154	7792641	0xf7c9745c3172f68b694dfd0160d51ae37483948e06bab9b7779e89cc58d3e711	2022-10-18 19:30:36+00
155	7792642	0x00c3cdb30a90e0bea48418c071fdac433360d99236a2317b39a234c5b4e19e6e	2022-10-18 19:31:24+00
156	7792643	0xfe926a8dd4e71d66b3268a7015ce563b2b62b41d15f4a8656ff0d1b13b05e114	2022-10-18 19:31:36+00
157	7792644	0xdda96bea78b679e4304183c3c24752128913b6e0eb660c067a92423d14f8e8f6	2022-10-18 19:31:48+00
158	7792645	0x77e3e6a867a4e422ccaed21f603877e389878832df353f43f711db63b83a6878	2022-10-18 19:32:00+00
159	7792646	0x5fd9513205b32e6463674ed6e4ae6388324ed861136d326f396799a37a5f0cc0	2022-10-18 19:32:24+00
160	7792647	0x8439c80c87c33e1232534daba83e12823d47f6829dd9ab17d69352ab68854b30	2022-10-18 19:32:48+00
161	7792648	0x3ec79488d664ec7e6f05396e1f1ada2f5358883da29e9169be413990c4bed67e	2022-10-18 19:33:00+00
162	7792649	0xc8cb23164489c3a87146771a72dce86cb47b31e924d616356e11d05351fa440c	2022-10-18 19:33:12+00
163	7792650	0x6697c1f1ac927a97d2b22caf5bec03ecb3762b20e9ccefc1b0c315e0d822658f	2022-10-18 19:33:24+00
164	7792651	0x6a55c56fa2ad9ca7a6229b4965ff153e3ccb30fdef7b2f386965ddd04957368b	2022-10-18 19:33:36+00
165	7792652	0x5f91bcbced50314991e6191bf2038a8da6110a06dacda333476389f7ee6c7fbe	2022-10-18 19:33:48+00
166	7792653	0x7d2f03e4690481d9feb595a6f564490dd7bd2960cb81f7ae530090c741f9a93e	2022-10-18 19:34:12+00
167	7792654	0x0e627311277d08bbbadaa26b0e01a7203dec54fd8c217665ddecf7c7b8b169ad	2022-10-18 19:34:24+00
168	7792655	0x20e8a1feb25714cf8030abf92b3cd32ea4931a5c08543091035a90000585f0f4	2022-10-18 19:34:48+00
169	7792656	0xa02d9feaee0defcf741d366fae34c8e1b996d42d20003aa97d71b9cf54bcc378	2022-10-18 19:35:00+00
170	7792657	0x1dd231f8cfc4c7ce10afee76367bd643b35964be0b217283470147edc367fce5	2022-10-18 19:35:12+00
171	7792658	0x528c61a87922a9752eeb6a6a166fb197d3b4849f68b72c96d5b6dd7651e85276	2022-10-18 19:35:24+00
172	7792659	0x36843e85804f7f70e94b1dfdbaee5bde16272df24e48a6588205ea9d6d6544f0	2022-10-18 19:35:36+00
173	7792660	0x4f1e64cb776ef131048d808a0cfb1153be57ea9295f6730db3977eedb194b8e3	2022-10-18 19:35:48+00
174	7792661	0x62a3bf8e962e755655f6217db1292ea6a3345b8fd43656864390a4baf545cdcc	2022-10-18 19:36:24+00
175	7792662	0x7439dde83e2dda6aece0c97d2b3ff0ae69cab52d2bcee969d685b4da0aba5c91	2022-10-18 19:36:36+00
176	7792663	0x2d5c7cacf02436e4604d57e9413ac130f02e121dc1de2742d789a7aa82328b17	2022-10-18 19:36:48+00
177	7792664	0x7004a8c6ca745840bb479a8d9e415a5b6c4d3ade4eb8557624434234c5d3b445	2022-10-18 19:37:00+00
178	7792665	0xfcf8cde56fecbe246274f759e172e5ef997a37cbaa2ae624d17ce489bdb38156	2022-10-18 19:37:24+00
179	7792666	0x473aa28a421652e05e78a774d2a7e50c81b71783afb75f20ec7baeae15810344	2022-10-18 19:37:36+00
180	7792667	0x4cac02351b2e3c53f71af101d062cc48ef8ba7956c2e2a6a7f8cc8f189f0ff09	2022-10-18 19:38:00+00
181	7792668	0xcaa37ed3c9c8f93e8b3a16cf5e744bf55814dd6eeb611d76eb82070ae2f567a9	2022-10-18 19:38:12+00
182	7792669	0xab0259c4d3c029fff2f0266e12e8b087979de8e5be64712e0e7cf2fdd8a3d731	2022-10-18 19:38:24+00
183	7792670	0xf75ae6aabc9f497f83066d24bf0ad4d3d8403dc29eb79998b4a08b10aafee3ac	2022-10-18 19:38:36+00
184	7792671	0x47acb10b87094edaf27a79926a30b495a83e6204c443a112b91e6bac55a2d014	2022-10-18 19:38:48+00
185	7792672	0x94b6e141344b61774c8d68c31d30f7970903232df0734875a08c1de10ef33346	2022-10-18 19:39:00+00
186	7792673	0xc707605491bc49bf1c16674cbeab1ff187ce34ebede075099e35c5b003ad6b47	2022-10-18 19:39:12+00
187	7792674	0x445696a0b7eee6d1c7f26df41859c6e3c2d0c703a59951af6f683ed7f57e7a71	2022-10-18 19:39:24+00
188	7792675	0xc6fb06f77f9cb7ccad55b8531b4f094626e57d15876ac09f7cae148b4e9088f7	2022-10-18 19:39:36+00
189	7792676	0xb800b6c30c54589ace409f4c37bd8cd1b6e863d7bbc2b9fbf6bcbfe025220c3d	2022-10-18 19:39:48+00
190	7792677	0x236169cba80b856d82f3077712d5ce8eb349cbcbe3abf083de137d2d408f5d66	2022-10-18 19:40:00+00
191	7792678	0x1daec04304e7eda2e167c782b1f79c70f62b837d0291aa30c27b71dc20d47eae	2022-10-18 19:40:12+00
192	7792679	0xd9cd053a30e4097bb319b514c7e118d1d5a19b233310250bfe226b6d82df76a9	2022-10-18 19:40:24+00
193	7792680	0xf30322eaae817eb3368dcdd63e9420410e7654c6554910bb115e523f7b454979	2022-10-18 19:40:48+00
194	7792681	0x35f6b3ef1796abe6e1ebc78eb7f1610544f739eb975d07a1f8ddd749280e5bab	2022-10-18 19:41:00+00
195	7792682	0x960bab65f821fb180346c9c32b764a9a704161d39ee648a132958a9ec8f9cc9e	2022-10-18 19:41:12+00
196	7792683	0x4e1cf24a0ae8c43ddad5c8a3e9223419e259b40dcf6e48cd4e9b25dbb7405c53	2022-10-18 19:41:24+00
197	7792684	0xc151b2f1996d5cb144a698a88395092a7ce09e7a442a7ba749d321f0e41778d2	2022-10-18 19:41:36+00
198	7792685	0x0505f97945d466b42ad5e5de4bba20a2fd7598afbb6bdd2b641396985a92a90c	2022-10-18 19:41:48+00
199	7792686	0x328d3a75056e907f973c59b31257cd8f95c433f1dd42aca65aba802c0dde3e48	2022-10-18 19:42:00+00
200	7792687	0x8b4049905b0e329fd4f184c1ceec861258e9f24cacc74256afb2d90416165757	2022-10-18 19:42:12+00
201	7792688	0x8b150a8da0a3867d798f4924a31bb5b11b0f3335968a5b00f0ac825af2316f7c	2022-10-18 19:42:24+00
202	7792689	0xbc94adb605f474d159c3ec5ab170d85b0630f4af3cacd2eccadfaaf8956e9b92	2022-10-18 19:42:36+00
203	7792690	0xcb4dd1efb6f679d7f5b74e811002ae6518b5e02e4c86431e8bc460bf055bea55	2022-10-18 19:42:48+00
204	7792691	0x859e31a2d95ee739e4c3fdc4058b3ae3f2ad9a5dea676730d19436df99ed25a4	2022-10-18 19:43:00+00
205	7792692	0x5bab55e39d4ed3b6a0ea5303b57ece96de21f061354217f451383231b824a779	2022-10-18 19:43:12+00
206	7792693	0xf98065b9429558420350af615c386b2547a7a0a6377bef2094ec3f86e9a6af2c	2022-10-18 19:43:24+00
207	7792694	0x6a506c22026342f654341a1f516f6c3a2dc40d7ee2c0c8815c8923978b7ccc27	2022-10-18 19:43:36+00
208	7792695	0xc1617786aa665bea48500c3a175069edb3764c86b37416fa0ea78de154264763	2022-10-18 19:44:00+00
209	7792696	0xe5e5954444bbde50a83ea52e241985116d0b2907d162660ec751299cb238ed86	2022-10-18 19:44:12+00
210	7792697	0x5d9ff0c16f18f3196f6816c4384186ab34546e8ac2b970bf19e98175235daf1b	2022-10-18 19:44:24+00
211	7792698	0xb9840f9180762a38e126b0c4fc3b6450a056a39a6bde3a37d5f08bf8fab3d3a3	2022-10-18 19:44:36+00
212	7792699	0xb8860d0f451242440a84b1c35aa8f81a34e7d333bd674512fb045c31cc1f7c70	2022-10-18 19:44:48+00
213	7792700	0x3a3d01448f6b07849cd679557076840425117992394326d19f0db8742e14d761	2022-10-18 19:45:00+00
214	7792701	0x18218d82ea0e1061f0d44fee5ad8a6bbde624841f3f494a61a202dca126cf999	2022-10-18 19:45:12+00
215	7792702	0x86e0be1816e09a6d6417314fce465d7a9355bda76830a7ef94348807b8817d44	2022-10-18 19:45:24+00
216	7792703	0xc431ac55919dd759ee380859a40d267a19af8e3c8be5f4c0f540ae9c0abcf156	2022-10-18 19:45:48+00
217	7792704	0xbc5da2ff1f6d2419663051d9f9ab27c190b427fcafb1d26bbedccbfcfc96a71c	2022-10-18 19:46:00+00
218	7792705	0x6efc104588ec9e92048553ac1a4ef5ddb2e3acc3f2b92f3e6ca23633311ca9d0	2022-10-18 19:46:12+00
219	7792706	0xebdfbc884f9b6909063e9b6834a884cdc3e9caa7e046e4698df755760f373da7	2022-10-18 19:46:24+00
220	7792707	0x5855620bfd4923b956aa62bb3b7d9242b82b9f6f5a6ae96ad6d2c3ad5042168d	2022-10-18 19:46:36+00
221	7792708	0xf06e82b4f8772e490286e7ec1c2caa60f1308e3c2c07e186fbd6f1220c9a1e90	2022-10-18 19:46:48+00
222	7792709	0x50bf2c2bb49b2af71ddbeb48e982de0eccaa7c62b49b1c954cea257b5ebbf57e	2022-10-18 19:47:00+00
223	7792710	0x1d32daafd61e72897689739165c50f7ec20a1e97116f3a7fb8f64b88f5bb0ec1	2022-10-18 19:47:12+00
224	7792711	0xe4421c1f71613871a40663ae9d399ac86e9daf1af31fde0f79591ab81cca0e76	2022-10-18 19:47:24+00
225	7792712	0x3e706cf2cd5667214bf8b7695f578871905658cde51bcafedf03cdfd1312f933	2022-10-18 19:47:36+00
226	7792713	0xf5bb368f37d9542a89f48a1e25d27e98301243324154d52ea9c87161b579b511	2022-10-18 19:47:48+00
227	7792714	0x1604509d1b7f5d586b9b25e62bc595791fa2ef1ae7a0399845c2ba1d86b88788	2022-10-18 19:48:24+00
228	7792715	0x99ee535f2309b944594029c7abbb674d9f69bcc82e6b52ea937753451dd73eb7	2022-10-18 19:48:36+00
229	7792716	0x725f975a1cde9e96b3ac1dcb46bd0dadacb2b98058f2f2bc46f0a6115471707a	2022-10-18 19:48:48+00
230	7792717	0x4a672d3c7314984f8a485aabc1b26c407a52b36062411de9d54c6e19e591733e	2022-10-18 19:49:00+00
231	7792718	0xb3bf50dc9b63f9167b10b6cfd10a6fd7ad7039eb18f4d95b06ca412c05565205	2022-10-18 19:49:36+00
232	7792719	0xe7e70a6750e6f9374f367160f64a7b9bd7cc204a2ad48fc6f1fa0525bf70b5ce	2022-10-18 19:50:00+00
233	7792720	0x43094afa949f72116f9dae9ef3eea5eac009860e09e3eb6b9bed7c2196fc60e6	2022-10-18 19:50:12+00
234	7792721	0xd5c10728b5a702c03d35c94236afadfc99f3462fb7e3cce8771d44b2a7e0d872	2022-10-18 19:50:36+00
235	7792722	0xd124eede7df357c65b9a57cb5f338a872a594ef05f046c303c4eddf39bede3b3	2022-10-18 19:51:12+00
236	7792723	0x4b7d9f6006f1d6295547bec30bf9f345a5d018643ef3c67927a4fdaa6ce3ca7f	2022-10-18 19:51:36+00
237	7792724	0x5da3b5debdfaa6d1cac0743650e720387a886e954ca9252ece77b68fa72847ab	2022-10-18 19:51:48+00
238	7792725	0x06ffbea21106835f21a67f63868669aa317b1fea78381fd0b775d6537b849054	2022-10-18 19:52:00+00
239	7792726	0x50eb821bd5451e2cd394be21626f0508d8823327782fc087ea0b9eaff562872a	2022-10-18 19:52:12+00
240	7792727	0xdb11eed0c8e94a14fbda9386f620b506c3ffb5eb2e60583b7a480b00b643234e	2022-10-18 19:52:24+00
241	7792728	0x6509fdcb2d03a25c44a303f8bca66672d8676f61af4c18c39707976e2fd135c0	2022-10-18 19:52:36+00
242	7792729	0xc8c27742089d989263c885500b1728d96f43d1ee9f9364436432897dac803e75	2022-10-18 19:53:00+00
243	7792730	0xe90cd445c08d444af1de304f2766dbb59c65ed2bc77e1dc92d2cd572328be479	2022-10-18 19:53:12+00
244	7792731	0x0443bafe071b93e0d18cdc1fa1874f3fa4c279e57e7faf9cb08c7c76f4a1657c	2022-10-18 19:53:24+00
245	7792732	0x0fc87507118361cf3a7b7a67be847fb6d41b3e7c8667f8ce8e8eb5aa8753b9b6	2022-10-18 19:53:36+00
246	7792733	0xcb29ff5e4f7c57a3eea8a016c7a3a3aa60f2cc3a3bb376bba68a9912bde888b1	2022-10-18 19:53:48+00
247	7792734	0x9a78d7f71d5e5afe706483d468df8cef4781417f05f9fe3996cf8a44a6a9f6b0	2022-10-18 19:54:00+00
248	7792735	0x0401eca8d4d63ee2d9c9945c8877876cab75409436c9e4c38614d116792d98e7	2022-10-18 19:54:12+00
249	7792736	0x87fa7397a05df9d5314b9a84131fceb92005a9c950641ee971902db2808f2e3b	2022-10-18 19:54:24+00
250	7792737	0x8caabe4e38da04caaf0d8d30acd0b23dea79ea8a70b0bc924b703649ddbce370	2022-10-18 19:54:36+00
251	7792738	0xf8e1ef1618167e48cbb4f1f4dd1c34a376fbfa6d816bf274d6d39cda333d2b3d	2022-10-18 19:54:48+00
252	7792739	0xbc90b0534121e82a7fe963f34330496a06a7a3c00b29b200e55cce576e2e7139	2022-10-18 19:55:00+00
253	7792740	0x4598ad811647c6a7f5a58cce1e2f8e891a3e4ff243fbdbeb0170e7d15ae83fc8	2022-10-18 19:55:12+00
254	7792741	0x2c9e5039e9e957b0bf87e612e0f15bd30e94cda9cea24714b469092975c6f0fe	2022-10-18 19:55:24+00
255	7792742	0x350385119adf8c31931f36cd75b6a5c7d0c68cdb4a971534ae061b0a32b10bbc	2022-10-18 19:55:36+00
256	7792743	0x05b7da372aedda408152a346c5ce755e3b3f0b012848d0059a8466ad504e683b	2022-10-18 19:55:48+00
257	7792744	0x4d3189fc8b7458740e5161e4e2b59422e5c11b6a00e7abf8371a8d6c09077582	2022-10-18 19:56:12+00
258	7792745	0xe5e2ba312ba1bf2663bc3c45cc1c898d8cb9dff34bf19cd1ae69ba9e746082f4	2022-10-18 19:56:24+00
259	7792746	0x64931f0d26afc368251d6fc3527baaf295ddb7dadd6ac9091d87d4c4004f1c81	2022-10-18 19:56:36+00
260	7792747	0x92e034165bc5f9a5125fc995b31f24004bc8e8f10d24308a209978a1b72593d6	2022-10-18 19:56:48+00
261	7792748	0x05b56797724180c36828f98ad5dd9c72bdc49b42c70e1e205fddee78620b0b7a	2022-10-18 19:57:00+00
262	7792749	0xbbe815b356a563f299e0e89b61f8f72435b3c54e9eead149e27d6bc580456eaa	2022-10-18 19:57:12+00
263	7792750	0x418a5fe702f0090a97f411e47dc6d995e20af0412d5149e8cbdda37339822eb2	2022-10-18 19:57:24+00
264	7792751	0xba2671a5b31f9d88132ce5a007baf2247edd3fe3612d056e37d6a3dac286dd01	2022-10-18 19:57:36+00
265	7792752	0xd925be9ef690020f977da6309a4abf20dd94f18707d47691bee560437af20d6b	2022-10-18 19:57:48+00
266	7792753	0x41bb40f168547413b2a4121a14fe5c4306c145aefc5869e8167c7a6054588c5c	2022-10-18 19:58:00+00
267	7792754	0xc4e4a4c9f97709f4e0a0d75585fd133b1b8349dc0031922410094871659cf154	2022-10-18 19:58:12+00
268	7792755	0x9e059fd186f5232c06b2a278ded0a4440c11be49ab91501a5b2b55535c0d6a75	2022-10-18 19:58:24+00
269	7792756	0x8f27d85a7435202faea55db7bd78042e0eb1ffc9df69585baea691b9aab46a67	2022-10-18 19:58:48+00
270	7792757	0x134a01b95667cb428be58a876f267be31f14bf379e63d40aa35c45056070d8d1	2022-10-18 19:59:00+00
271	7792758	0xa7afdcdad020e19347c50188a25b3910043fb14b2d412d0daf989c5cecc68641	2022-10-18 19:59:12+00
272	7792759	0xffcf9d5a52e6843cf48b0231ba947844d79a3ecee01253b49ab523ef03ebb847	2022-10-18 19:59:24+00
273	7792760	0xe6d613cbc198fa66b50a9bcaeff5a241f5e5913ffd19cbb01c8d5faf12e7903a	2022-10-18 19:59:36+00
274	7792761	0x5bbe99d7d7894861014912a3ccc152ee33d87b7997c28d57697efe02ad219f91	2022-10-18 19:59:48+00
275	7792762	0x2f3e66b43649ba2529e78c162b0a351a9c1013e8c9f042de9ba58e953d9983d8	2022-10-18 20:00:00+00
276	7792763	0x04974661ec01693b7ddeda06b358fc963114087de17caaed0d91101bed3d97b7	2022-10-18 20:00:12+00
277	7792764	0xf46c15ba2d371cf74db779899aaf91ddb3492ef7be258c1449afb26a50021587	2022-10-18 20:00:36+00
278	7792765	0xed116b15eec972ccccbb4ce486026dd15cd0bd90bbd5b24df209e6fa36667929	2022-10-18 20:00:48+00
279	7792766	0xd6615c6f79c6c9215d16b10210615e4635ba4aca00998ada52b94c0beeea0ea1	2022-10-18 20:01:00+00
280	7792767	0x23ca1442961c521611a02609e655a0522d55838e6c07ed9a1eaa242cd4387379	2022-10-18 20:01:24+00
281	7792768	0x0c9f623d127f66d8bf4dc77695b8fec05646c40409e921f9ab092cffa87f11ec	2022-10-18 20:01:36+00
282	7792769	0xeab6f73f8a98632c177e2733518c764edfa4d51d593345b76e35b088a9d469e9	2022-10-18 20:01:48+00
283	7792770	0x4f3128b6fcca6d75e97a0ea8cbc74a24868ff5e8f64f2324848a23d6802ba386	2022-10-18 20:02:00+00
284	7792771	0x1b8a3ef47bcc785e722fb13febbc2a3d7ac93cc7744c3f9a4212987c0878e6c5	2022-10-18 20:02:24+00
285	7792772	0x61355bbf49a304101291729c65ad3799ddec87fec26549116f59ff7b98c0672d	2022-10-18 20:02:36+00
286	7792773	0x56b8ff091d9039aa325c000c6aafceeec206c8617f0b2f871bf6d1b3ae0d57f0	2022-10-18 20:02:48+00
287	7792774	0x69960545dbd7566d711699bc8190257a7e0f6e8536c36795234bfdaeac06b20a	2022-10-18 20:03:00+00
288	7792775	0x693cdb9e35ed2c03eb9f3ae6c32d4a26bfe8d89c20dd5010d46b2bd6d8cfb89a	2022-10-18 20:03:12+00
289	7792776	0x5c8cd6a2064f771b4ff69c572ed7b90ec95ba30c65126b4aef0518dddef231de	2022-10-18 20:03:24+00
290	7792777	0x928fbd0524c3c220af924076307a27e10eaadc3d73304c92cac17e2860781737	2022-10-18 20:03:36+00
291	7792778	0xa97daee02832fec53fb9b31347e317756c4a4aa1f54e2f8db2abf13a29af8b64	2022-10-18 20:03:48+00
292	7792779	0x00b52cb82ae122162a7d94bd2c57a8816056ca6a08f4695a8ae484fa9b6f6e85	2022-10-18 20:04:00+00
293	7792780	0xa5d1b88296b46d4b7ed1f107bc580879216e469499b20927b1252e1dd9b5a28d	2022-10-18 20:04:12+00
294	7792781	0x2d5f96f7decd8a24c5221a11aa4aa8f939237da4bb587abf960c43a4a19300ed	2022-10-18 20:04:24+00
295	7792782	0x68df2e386dc8badd364310075cd5aad28c50d077b4947679c3ed7adb45a41cdb	2022-10-18 20:04:48+00
296	7792783	0xaae432a505e701c3c954c0eb12dd0f2576cdae6a8655d67e4adf5a5c145d1e0d	2022-10-18 20:05:12+00
297	7792784	0xe9814dbbf99111e82f1545890cd24f02d38fa19486c71f77853c35a6cff0f87f	2022-10-18 20:05:24+00
298	7792785	0xa72357a6cc677f388f61e951fc5e1bc22d50d3c93509cc3b2ea7f30215ece1b1	2022-10-18 20:05:36+00
299	7792786	0xfb377b03fe05b4817ed8de099a0d977ad27bf7d062176c933c44b4bd8bc4c565	2022-10-18 20:05:48+00
300	7792787	0xbaae880ad5e7d811a3851b5d802dcecafe8596955445c2377ae178c140cc5313	2022-10-18 20:06:00+00
301	7792788	0xab8bace63e48c4c13667ce6742817f7576f55f949bafb9cb4dda9738e9770a0a	2022-10-18 20:06:12+00
302	7792789	0x4b93e939d2967969d15c2abb8399290b9b401e747e07bac73acaebe179fb7874	2022-10-18 20:06:24+00
303	7792790	0xfb23bcaa92409cd3537c6798c37ca1cc1ddc8e56041452ca251682a329a4252a	2022-10-18 20:06:36+00
304	7792791	0xe55eb6f0dd9cf0969c4bdf1ab788a041110ce15621b39eeb98478b411a056e3c	2022-10-18 20:06:48+00
305	7792792	0xd720ec3e6ea2551c797285541fa42d5d1475bae98160dea1b9748dfa3d5a9051	2022-10-18 20:07:12+00
306	7792793	0x3a433dd8d3f30a7b8b5069e494054ddf01bf6f215f5fa582dbac006c709c4178	2022-10-18 20:07:24+00
307	7792794	0x099342293913990caf0fc64b3a8e2c06d5daae9fbfdf2541658703967a3fd6f0	2022-10-18 20:07:36+00
308	7792795	0x1cf69f1dfee57cf82774d54f0be83bc8e6737434a4409d22191e137898c1304d	2022-10-18 20:07:48+00
309	7792796	0x0e4661c8362fdd7379928a1e220b83860a2e55a31372c362fc7ae059d901efd2	2022-10-18 20:08:00+00
310	7792797	0x5b6864c5cf54a733cc1f5e1ae247f35c1676ab261ab6629acef5aa0cb7e9a444	2022-10-18 20:08:24+00
311	7792798	0x4d96f692284ac42e9578a3e4e7e96a72f04ce7cd4ff4233cb4baa71204dcfc32	2022-10-18 20:08:36+00
312	7792799	0x4472a3b4a8324eb18ebb0c0289aa0aaba3bcd07cad67873103f263f228298a34	2022-10-18 20:08:48+00
313	7792800	0x95f66ab78c6e9319a5ba6c106f1fdb7e9bee1765b9af8bb596fe07130bcbbd8a	2022-10-18 20:09:00+00
314	7792801	0xedbf58e13ace00b45a87341f4a447e643c373c5ff05bf39e1b041e2f4f107a5b	2022-10-18 20:09:12+00
315	7792802	0xf2480102428f5943acc1baa4cbe908b5f317757ee46172b899bfc8400542eebc	2022-10-18 20:09:24+00
316	7792803	0x385ddafdd8693ef32aa54197874cdfb6b8362438b077564bfc12474cbe6470c3	2022-10-18 20:09:36+00
317	7792804	0x0deef8c623ce7e5e0610cdd54862c0d807cdf3494ba861f38be584e09ca2c388	2022-10-18 20:09:48+00
318	7792805	0x923127ae801be51a2732af7229e16d7863f5ddfa37926b73b1a3a7ac0398438b	2022-10-18 20:10:00+00
319	7792806	0x50abed0d81c81f4306f017ea1455e55c22d3087ee3b203f92c21a8c501afeb86	2022-10-18 20:10:12+00
320	7792807	0x80cf75c24b2c3e07bdf3bb4ddb7376a261c5378bb11b3a45d9525ca879feadcb	2022-10-18 20:10:24+00
321	7792808	0xe3ef32ee8c9f013494bd888cf4b6323dc94c166328d257fac5160d3d00b86e27	2022-10-18 20:10:36+00
322	7792809	0xf15e9a8c96d78438c41f725f78b3d646941966aebe9163f39fda378d10fe81e2	2022-10-18 20:10:48+00
323	7792810	0x470d674f4c4390232f21847eef5cf7455c9a117c5cc69ca83ca67aabe670405b	2022-10-18 20:11:00+00
324	7792811	0x5a71cfefa072186da09458c5dd01a58eb89f0e348945be73cf6c328af54e1101	2022-10-18 20:11:12+00
325	7792812	0x064aa250b786241dd156a61c71dd6ca4b60aaea5aad172c91a2962869c47dae0	2022-10-18 20:11:36+00
326	7792813	0x028b377331af97022d1d37b8e215b28a80603b0e1dce31de1ff385a37f19316a	2022-10-18 20:11:48+00
327	7792814	0x275a15dd744311f53c24a751d917caa7a7c7a02caad44a03c2b5b80caa6f649e	2022-10-18 20:12:00+00
328	7792815	0x83184ae68812e18f648a7c40df5fee6153e4a23f5fb6ff5173a76de26897298f	2022-10-18 20:12:12+00
329	7792816	0x59551b11a4af7dbae69adc507feaecb9e007e9472dbef253b69ad4bd546091c7	2022-10-18 20:12:24+00
330	7792817	0x054e0efac91b97d3446c222b41a13afdb083a59e673663927b126d19f475fae1	2022-10-18 20:12:36+00
331	7792818	0x4797b92c5c8085030dab216b5a9f802761f06eff20f63374acb7cc8cef51c496	2022-10-18 20:12:48+00
332	7792819	0xc705042a33dd1ba8735186fbafc7bf7cdeca35b17434638a2084b43855c3c657	2022-10-18 20:13:00+00
333	7792820	0xdc4af9e72259043e2138fc5c289df0dae6740b704b554e469888867f2ab03c4b	2022-10-18 20:13:24+00
334	7792821	0x95e184197b82f94aebed48452b35a1bc231458cf495c2dcd2aa98d8d96fa2bf1	2022-10-18 20:13:36+00
335	7792822	0x92fdd318cce689d03b7d178d79f05562d15f6bcd5a0292f850a723e344d10fa7	2022-10-18 20:13:48+00
336	7792823	0xd8aa11b2836a3f69335b18875c6bc980c1650e27951c02516318cecc10da7d61	2022-10-18 20:14:00+00
337	7792824	0x2afd703dde106f56fe66b1d1fc8aef2ab60b14b7d44610694805fe2fc87da00e	2022-10-18 20:14:12+00
338	7792825	0x0e8f29506e5e80a1fb945affb40c8671ee304fe6f3c9d9b38ed1f14cfad9af78	2022-10-18 20:14:24+00
339	7792826	0xf54dce732b2b71035bf177b12adef04f7c3d276728331f66832ca92996d2ad9c	2022-10-18 20:14:36+00
340	7792827	0x9f1d29866fa76be9d548cdd648511c4e3ab455bf61c09f5c32c3daf3f14e02c6	2022-10-18 20:14:48+00
341	7792828	0xd5f94ea51f59d2f49ca82dfa9a04a44ebecd57e6e62a5c2fc749bc9da5c764d7	2022-10-18 20:15:00+00
342	7792829	0x7c343d4cf7f2ed18d599d27a04b86f6abb78edc982dcb7a60342d132806153df	2022-10-18 20:15:24+00
343	7792830	0x2d0a39a2f2c18c39125cabe8ee8a511390a1c41b439e1181734f48718ba6ce80	2022-10-18 20:15:36+00
344	7792831	0xc1e9fb686de075d46bcdcf7b8d15171b66ce83d2556c26140aa65c5cb457e6d4	2022-10-18 20:15:48+00
345	7792832	0x5004e6a391dfa7bfec4b554395eacc6efa5230f2d18ed0f21c63c267699625a1	2022-10-18 20:16:00+00
346	7792833	0xbf345d32d6a06e1fc1e49f8a98f392cad7221eacdc2de3b68ac786416df4bfd8	2022-10-18 20:16:12+00
347	7792834	0xc379e95341fd769e1ad3d5b97565b6ea993daa243dde20436136d52fc4bcb9da	2022-10-18 20:16:24+00
348	7792835	0xb4989b5a73adbd3a31ef4c697d5c55642faf23a7d27b9c2329feb1895fee5adb	2022-10-18 20:16:48+00
349	7792836	0xa11fa29f8b8860b349b442b12a819245976df1f4af476e624af2e687e68549c5	2022-10-18 20:17:00+00
350	7792837	0x87462dd0d1f2a44485d4f5b3a1926f09837138a7c03fbba5eda02bc97a5ba5c3	2022-10-18 20:17:12+00
351	7792838	0xc518ebc4a9029974222d22a3073c296953c808587fe09f07fcf1d68747407bde	2022-10-18 20:17:24+00
352	7792839	0xbfeba1faebaee36fd7661082bb83e0b4126b658f1014cf66066748987f006f89	2022-10-18 20:17:36+00
353	7792840	0x32c02582e7892e1bbd85970f8232039512c16af3c5de0c613a59a01e618a633b	2022-10-18 20:17:48+00
354	7792841	0xb9b59117f47cbba99dab2a92e4fda902470beb7d48d32fdc2640a56f889f24ad	2022-10-18 20:18:00+00
355	7792842	0x424503d4bdd05deba39bb19e97ae889b827aa3f26a7c5554ac49b851f5f6de11	2022-10-18 20:18:12+00
356	7792843	0x06d727758c7f12554dcb845572345b74e38d39a27c3f5bc085e1b9b9cf86f882	2022-10-18 20:18:24+00
357	7792844	0xc5fb72fb64a5164ac4828a112cba897f32d5b351fe9fb19ebeb747748d9adf79	2022-10-18 20:18:48+00
358	7792845	0xc41e9992df96f713cd459241d1ebbbed5eb717e8983679134d1d6cd2835eca50	2022-10-18 20:19:00+00
359	7792846	0xaf67a1853459a07cc1433c7595e4cbc1e0a584db24b696490596b9d08d52aa2a	2022-10-18 20:19:12+00
360	7792847	0x9b45ad0de9e80fa11d3c115a1e5479016236cba93cda1343928740c44621e145	2022-10-18 20:19:24+00
361	7792848	0x9d9c4b4c00ef9cd805c2c9b82c6cca877553ddf0286e3fb586a3d93bdf219fb9	2022-10-18 20:19:36+00
362	7792849	0xea1985cbe74cc7693558457274f30717e02ff9ec4404df6bbef6a4b2b548413a	2022-10-18 20:19:48+00
363	7792850	0x2a11a902c635371823b1c277732463e7e6cbed722f16f42b4e30c9b0a9fc5528	2022-10-18 20:20:00+00
364	7792851	0xc8eca75019edea546c616df6b4e4fbcbb4b7bdcc7ae8be4897764169b9d3b0d3	2022-10-18 20:20:12+00
365	7792852	0x8a3059dfee40001e0e84297da7a83b95c2d0fa790c307cca4e86526c82117959	2022-10-18 20:20:24+00
366	7792853	0x15850c417dd804567959ef2df781e8e8594480d233949354f882bdf85d5a5301	2022-10-18 20:20:48+00
367	7792854	0xb4cd4abf8615ef67b24b546ecb21930ec41363380088e38a99b0c70fb122838f	2022-10-18 20:21:00+00
368	7792855	0xc313527896f8a25e19b1278bf4b7f491058f0a5ffadbd9848655cb2e9a60386c	2022-10-18 20:21:12+00
369	7792856	0x13cd8df4313a0290148084cfdaa213918ba9b2b4022e11fdffc3fbe79f6c2846	2022-10-18 20:21:24+00
370	7792857	0x95764d2045622a8b0bd1fb5cb831592d0506081bd3312de559f3473d0c74bdb1	2022-10-18 20:22:00+00
371	7792858	0xb9a14bc564cf7784e38b93d27f5beaa5e0181d24d15da6b3df5574538ddd6517	2022-10-18 20:22:12+00
372	7792859	0xbac5ceb2c0704773eb06cb876c7fff2add89c3911e204a77af4b9a4e8e6acd1d	2022-10-18 20:22:24+00
373	7792860	0x545ba49e434a07fbe2878d195be746db258520f7d5c69c4292cefaec42bf7c8d	2022-10-18 20:22:39+00
374	7792861	0x7baf29250d3c4cd51fce17ca4c2c4db982c818f578b00cfa35b0e23fd2f959b4	2022-10-18 20:22:40+00
375	7792862	0x1946a34c1b9a2b34091bc3b2bf885c3c5adb96848fe68a0ef9bad8a21c0f6b52	2022-10-18 20:22:41+00
376	7792863	0x4a1cd77f759e93e9894173db9445e639433efc97e8272f79b44d9b2df1e72e2c	2022-10-18 20:22:42+00
377	7792864	0x97c327b5789bd80bf946b3e671044dc3f438a145ebfeb2b9b4b6a1eecee8e4fa	2022-10-18 20:22:43+00
378	7792865	0x63eb396a487c18f4d710e4ae45e91b0ba1f8408e85dc3e7e765d4da46f784fc3	2022-10-18 20:22:44+00
379	7792866	0x470298eba9dc7edf152e942dffd874e39fa90d240845fd657ebf5a6277a861fe	2022-10-18 20:22:45+00
380	7792867	0xabf198b1c1dbde78641169a84be5c557a018c5965d3363924964c22f76afad28	2022-10-18 20:22:46+00
381	7792868	0x4affab3252fc0eecdcc5392d89af378f9c12719f3495d69bc252fae43a4e76d7	2022-10-18 20:22:47+00
382	7792869	0xde699aa2317ce5a3a78f1a2537b454c5ef8be456dc17992224e8c8c1fcf5d510	2022-10-18 20:22:48+00
383	7792870	0x6caa53541ef33ed72b811bb654ef140c3251d66ba3126efb7bbc134eaf79eef9	2022-10-18 20:22:49+00
384	7792871	0xd58db9e70ea0bcd115706fe2b7df2c02f1a69255f1c50265058cb3e69b5f8987	2022-10-18 20:22:50+00
385	7792872	0x8d40255b2bb8b9e27f64c79c8b36b685d9c125a5558ea84cc5405f4430811bba	2022-10-18 20:22:51+00
386	7792873	0xcb25b0fbbf1090703f58a864ba1f1ffa6da95b1fecca396ac7fa1feaaec9a9a4	2022-10-18 20:22:52+00
387	7792874	0x306ec1042f8ea0a709369f6aa6b923cc1844a25da5c5293e3f9489c079a1cc0a	2022-10-18 20:22:53+00
388	7792875	0x7c6c6dcfe5538e20c60c5c5b30eae70f119d3f5527efb56286a48da0981efbfe	2022-10-18 20:22:54+00
389	7792876	0x169d6433c8b89e80f39115e5d62a26943118c738cbe915e7e1541ca016ed4cfb	2022-10-18 20:22:55+00
390	7792877	0x792e2a6b1d99a1dfb13f06df28a0ca4d2056d27a9630d1da435d793ebdcfe8f3	2022-10-18 20:22:56+00
391	7792878	0xb9d0126f69cee9d65dfaca90c8260128625c7769336a19a851cba7b7fa4891c5	2022-10-18 20:22:57+00
392	7792879	0xa3e0b50c45ff674e4f2d108d1260e28295b10326022daf2dd2266e7140a92204	2022-10-18 20:22:58+00
393	7792880	0xdcae47ca340fbbdcb54dc6468b93ef22ea081d09b4e3f73ad4556d5ea8ae8962	2022-10-18 20:22:59+00
394	7792881	0x81b9bb9caae51377a1d56364f4d33651c720fffcce4328e666ef32af519d1822	2022-10-18 20:23:00+00
395	7792882	0x5ba571f836b656ed8af53ec22a8957e6b7d978bb4b492241533ec8dd7329f7cf	2022-10-18 20:23:01+00
396	7792883	0xfa959e6792cd75307e8625bee6e99402857057f862b26d14b92d218ee609ff40	2022-10-18 20:23:02+00
397	7792884	0xb2fa6dfb4a8ec605e743a44d45aa38aa5e4af0d55234c755ea9a7d36a5d75abf	2022-10-18 20:23:03+00
398	7792885	0x340b567e42b84413b53fcc7fcb7a71a6d9694705d80b2a275ef2692b6e996d9f	2022-10-18 20:23:04+00
399	7792886	0xd87d1555e21a99ebd458675b42766ae343195c9b999b03dc3a4a6d4405481280	2022-10-18 20:23:05+00
400	7792887	0x56101443682124b1c6f2c4f964781f1b840b0f6ef9d8c6203ff290d144f2b774	2022-10-18 20:23:06+00
401	7792888	0x1d62a17fb0242e5b79b6948172eec6a4e4f052e185964509598ec1cf0bb55190	2022-10-18 20:23:07+00
402	7792889	0x5555d6d03d77591fa3086a9a99fd6965488207c13c0e7e681f5449171ddca504	2022-10-18 20:23:08+00
403	7792890	0xcf6facdef346cd6a0ea3c1e9e1574e93b394c36aa7a38c310b5f94fbcce8f68c	2022-10-18 20:23:09+00
404	7792891	0x16fc16b60ded44df108b9aeba7e3c20486dd9b307a33de91d03d6df900fae371	2022-10-18 20:23:10+00
405	7792892	0xad0590dd4c1cb18196c7960b61440fbdaec536e485e7373e431a978fe70d292b	2022-10-18 20:23:11+00
406	7792893	0x05325a50b4470852cb2f9fd008298b0166e33db1ed45166c05e49f2cb643a788	2022-10-18 20:23:12+00
407	7792894	0x88d4594e7a5b157283ddc4bc3c1bee9f14a5a24073f688b266fbbfb29bdf288e	2022-10-18 20:23:13+00
408	7792895	0x632970ffb127dd600c9491f0c90d69bc58d9df8f2ba3f96a5755bdc63975e86b	2022-10-18 20:23:14+00
409	7792896	0x617729b170959054a7605bd69e9fe7e43a549e353eb07083cb17f5cb682d7e07	2022-10-18 20:23:15+00
410	7792897	0x587ced695c1ded9792ce18ef7e088daf37fe2b446717347cbcad9f352e061b64	2022-10-18 20:23:16+00
411	7792898	0xfb994dd960fd297d58a0a3c2d8d7e33112651887656f264655bd78aba521dc79	2022-10-18 20:23:17+00
412	7792899	0x61efff0052290b8d5a496bea3fde05c11785b10f6f8cc14aa3156c11f68b88e8	2022-10-18 20:23:18+00
413	7792900	0x1a6884b436cc41270cbf60580b2165f5d53e32b81bc15ee7c73b1b30bd995b28	2022-10-18 20:23:19+00
414	7792901	0x0d0624eb1bb554052af84ae3ce7547212dff63ab564746b1c4b630b48937ec60	2022-10-18 20:23:20+00
415	7792902	0x2bfe203f46525c65242ef0fe0aecc8cb31406889ffbcc4f7f90a7cc5abad0629	2022-10-18 20:23:21+00
416	7792903	0x8f859144303f838b13b98a61ea38d212e98e5b4183d46e61128e8bed131f4f36	2022-10-18 20:23:24+00
417	7792904	0xf1a5088261adf9ed20557ca6d6a7e871842bbc0c7baf528537a3bb699a5b5b89	2022-10-18 20:23:45+00
418	7792905	0x2ad91daebe4916bc9bdfdfdd3d7523fcc2adca3102f425a69630dece4e74c557	2022-10-18 20:23:52+00
419	7792906	0x8d96cfeadac555fa70217e89c9932cdf35a2cf3c55ea98a2ec1506cbf9b50626	2022-10-18 20:23:53+00
420	7792907	0x6e640b6d580f2789088764281014361a5957d5ca47725346315492f14059996a	2022-10-18 20:23:54+00
421	7792908	0xac4a38e4fa0d472cc2a2305184f91ef3365e4306b5b7a3b304a7fb0e51e01a2f	2022-10-18 20:23:55+00
422	7792909	0x8ddd7161a504ea3d3fc2d5fa02404174cfc97850ec4d2f415f8bad6999c481ae	2022-10-18 20:23:56+00
423	7792910	0x7a0c73d5b19776b0d6905fe0c0124a4086b4e859189579b34f73b2eb72f58c06	2022-10-18 20:23:57+00
424	7792911	0x8862922fb58e683685d1bb2e9c4138e2533ce0f41d6746b7426fe032fd6eb072	2022-10-18 20:31:25+00
425	7792912	0x4a2c13c2ba9265f6df8f73f0a7e490713420a5543d15194c93b6877633248045	2022-10-18 20:31:26+00
426	7792913	0xf57a31c61b42745a43dc757bceb24672681dce7b16b9ed8752f9acf28c3c64e6	2022-10-18 20:31:27+00
427	7792914	0x5a82ce6356fccd598fb8606876650fde2c11b59dd78835ac37a5cfa3796ee452	2022-10-18 20:31:28+00
428	7792915	0xbf04f1aa73532b5069051443290e287ce994ebab7ba8a05ec66e1aa2e974c1c4	2022-10-18 20:31:29+00
429	7792916	0x26d5e87327ca1e0d3d10f4db68b2a8413bf367d1ceb77a4c5d367eb4408126cf	2022-10-18 20:31:30+00
430	7792917	0xe87b560bdfc9686d31f28ee0f0b22386c6a79ddc101db2562e634b0888126132	2022-10-18 20:31:31+00
431	7792918	0xad21fd711fbd14f7f2936b337f025bc056b775eb232e8af25b25fa7ec4efe2aa	2022-10-18 20:31:32+00
432	7792919	0xbc466865b0d56cedab3af84b260f0153f817a20d391414179cbe04f464bdc523	2022-10-18 20:31:33+00
433	7792920	0x51fc0ea4a2ac242c5dd2af0e90f48a250e4db756494af0b9aeb8c5814f4c029e	2022-10-18 20:31:34+00
434	7792921	0x1862a2f10885eed6aff8f342b3c376587d283652bc4a3d7225e3894ed8504a4f	2022-10-18 20:31:35+00
435	7792922	0x710a87041bccb43a3348689c1f2b3bb328dc7f9b9d49e2947a110f8f17bcacce	2022-10-18 20:31:36+00
436	7792923	0x8e4a0c8fb7d187ef9c9ce7e052cd534b73c757d0b29d532e2f6ca7ed3f8d36e4	2022-10-18 20:31:37+00
437	7792924	0xceda58247fa679c21a2092a78c8899da87e427a94a19e917aad5350c47090539	2022-10-18 20:31:38+00
438	7792925	0x2a03b90feb15a215c2634ed8a283c2da82dc90b7ae4df6d037bfdcabaa01f441	2022-10-18 20:31:39+00
439	7792926	0x7e21aa7a0d4d3a614b24606e640fae87f2980c85c2f01d8550605bad58fde2c5	2022-10-18 20:31:40+00
440	7792927	0x3d68268d796a14dccbee7960694133240f498e0eceaf7392fc187a351923328b	2022-10-18 20:31:41+00
441	7792928	0x85546c2338bfa430554fb73a6d6c5cb49a261eb418b84f933030a6087da84292	2022-10-18 20:31:42+00
442	7792929	0x3afce542a6beec7ce50a643cca55194b2765ec848a41c5934c5ef57366479de6	2022-10-18 20:31:43+00
443	7792930	0xe63923922c0816d4fcfdbb4211110bcf844660e2e4e3c72169c96fcc9764b0e7	2022-10-18 20:31:44+00
444	7792931	0x09093e637400e6895fbb231bd05851fe27410a9a4b6aaada296acdbefc709223	2022-10-18 20:31:45+00
445	7792932	0x571783301cd85572db874f358b057856c504f8e31a8084e2f9eb5777da3e4516	2022-10-18 20:31:46+00
446	7792933	0x8387c9b9bf715508716ee658ebc2c05d35619df7fa3756616e3c4335309f6cae	2022-10-18 20:31:47+00
447	7792934	0xb1470a91e14b791aa30f4379418c780ecaecd51c36d9a274128aa6d752097b7b	2022-10-18 20:31:48+00
448	7792935	0x1baf54808eac15dcb8151bedae81c514f0eb1e5b900439d6b1e26fdcfaa62f7d	2022-10-18 20:31:49+00
449	7792936	0x211f6a0a6572dd40b28cb3ceef647793159eba38c5cac61a665826860db91b2c	2022-10-18 20:31:50+00
450	7792937	0x4590aa6003b741bf2fdbddbe3e1613ca82f8f9806b68255b9dd7f2701bb7fa47	2022-10-18 20:31:51+00
451	7792938	0x4a9cbfb0be6c9dd5cad3a68ed0eaeec0e9f0b39c780ec9ca9ca62479c64d9171	2022-10-18 20:31:52+00
452	7792939	0x2a5e7100ce4f1e3e0e14a0c7da9a2596882fb580e273634f0d0a566189bc15d7	2022-10-18 20:31:53+00
453	7792940	0x6ae09571e95997a2843fdde64c851ee8b64489d4eb5d56b880f793c6fde7274d	2022-10-18 20:31:54+00
454	7792941	0xb23f658f0519024b3689aeb77c9fe0428579a5873e948f10db35f61a895479c5	2022-10-18 20:31:55+00
455	7792942	0xf3d84df5ed592496ab6ede8322d1d08d8c723129af130c5c027d724f6ed42bc3	2022-10-18 20:31:56+00
456	7792943	0x3c3cdfecdd1361f4cb0980f29fe399f13ba0563904f842883b8445fdfa6f5269	2022-10-18 20:31:57+00
457	7792944	0xf8764f545c7e63c5fa4585433771dfe07edaebc606d4ecb7501402132ac64538	2022-10-18 20:31:58+00
458	7792945	0x027ae1f2a41e6872006d50000f592b8fc79b95eae05676342105afc11842dd05	2022-10-18 20:31:59+00
459	7792946	0xc6f4e1da7267c29dce5a1ba1404cac2038999b9720e0f5e19322b0b3e4d81627	2022-10-18 20:32:00+00
460	7792947	0x53d9348b691ebcf69cc05210f75bcc3657b9426808660b0c2210161527247aa9	2022-10-18 20:32:01+00
461	7792948	0x2470f84d27307b65902465fe1f4f8f114c483ab712c65f22658092694c036bf3	2022-10-18 20:32:02+00
462	7792949	0xbda479f4c1aeb8a94f8fb485c697ead6033962f3d498dfce754786e276ab2a52	2022-10-18 20:32:03+00
463	7792950	0xa48372448568bad812e40f6323ae45e76aaffa6545a7a3a67fc343b2366392de	2022-10-18 20:32:04+00
464	7792951	0x7fb6790136ad133fee6d1f9d6613a9ebc7294cc637b691474342be1a20609c52	2022-10-18 20:32:05+00
465	7792952	0x160560c0dd2936e8188474cdb2818dbe056614aa14ed6b54ca4b401494ee75f3	2022-10-18 20:32:06+00
466	7792953	0x8cd91e50915a036006bb15a724be7883498d2e663864ef29fd59ef191326b553	2022-10-18 20:32:07+00
467	7792954	0x0d95e77a98ae50dd919aec337ddb2b8109612bc361276f0ad8678c0cbe6e7e48	2022-10-18 20:32:08+00
468	7792955	0xbe4ce474061bd30a42c4c48ee0fdccd3e297ae793eb5af113cfdf0acd95f30d5	2022-10-18 20:32:09+00
469	7792956	0x0b6998d424b003fe7f67628182dcf1b743eb58a04cc2e102b3d7a0d9a8ba56ee	2022-10-18 20:32:10+00
470	7792957	0xb09d534c63519201838446d11acfc71d75b9131b4505413acd81c7dd1de8ce95	2022-10-18 20:32:11+00
471	7792958	0x359e8e1fcd1aaf3e624e230ce1eefcf17962efeaf6ca005a58a881514356eba2	2022-10-18 20:32:12+00
472	7792959	0xe48e604e4a99ed4f04e7a9b597217927c25af2f4f0fe528fbe0ec7ff4acd737e	2022-10-18 20:32:13+00
473	7792960	0x590c11bd5848cf9fa29f5fac7475d1db87bdba66b99ff2f35276108eceec6428	2022-10-18 20:32:14+00
474	7792961	0x29e1621e32574e03ac40eeb80b5de8a51cf5ff9f201bcef957007f0e20696fc0	2022-10-18 20:32:15+00
475	7792962	0xfea0ae14f726bc80eb067493841cc899d9fab31357ad9018fa3b2ff43bc348a4	2022-10-18 20:35:47+00
476	7792963	0x6827dec6ddc6719bc6ad750181653f0d29f7499409bb323691cdb3b0eb0aa88c	2022-10-18 20:35:48+00
477	7792964	0xa3842bbcbb90af5e0bc777b51f9702355240361a1ed4da7f18202caab6266ffb	2022-10-18 20:35:49+00
478	7792965	0x9ab7f2b8ab70156e018e674ec3dcf8258583bce1cbc99a83b185da0b76856cc6	2022-10-19 19:52:25+00
479	7792966	0xd1ee427a04b24e1c82cb94493a52f7fc3db24c91f605b3e1b4a8593c5087f88d	2022-10-19 19:52:26+00
480	7792967	0x046f0b9bbba4db708473b27f494dc168f489f6ba2f97d37de13424bda8ffda74	2022-10-19 19:52:27+00
481	7792968	0xb7dab3e5c12d1d10745c57626dd92e7c42a4aaf23e37355bc355f6403e07251b	2022-10-19 19:52:28+00
482	7792969	0x3b3aa3144fcb720d55fdbc055b96932cfdf52a9c43bb8e7df7cacf89ad14beac	2022-10-19 19:52:29+00
483	7792970	0x6183b6621dee54cc72b2dce9fb5e417701858289aeb6cb19429cdaed9714e215	2022-10-19 19:52:30+00
484	7792971	0x4346ddd338bfa6623b94b0aeff6636161c6812092a42aff14489df8500fa82c1	2022-10-19 19:52:31+00
485	7792972	0xed2cecedea7a2019f62dd124d0a2b73d1a470b4092d44afdda37691af7551d39	2022-10-19 19:52:32+00
486	7792973	0xd567c3141966d49569b796f7e0ffcd0e7fb00c30ee76b2c4e384dfbe62ad0a59	2022-10-19 19:52:33+00
487	7792974	0xe6117d6a4c665187e50e9916f7d5cd66944374077829c29c55bec0558b1ee0aa	2022-10-19 19:52:34+00
488	7792975	0x48ced0471ac2bf3eed8b9fe89b766f2a0569731c69d0283381be579634c360e6	2022-10-19 19:52:35+00
489	7792976	0x88058da37fe13c26a83dd04796851eaed47e3cc787cd6771813a0ff8fa733090	2022-10-19 19:52:36+00
490	7792977	0x93253bead0c76a9c04496eb029057a641c9f5123f997963518e122dee9b8bfea	2022-10-19 19:52:37+00
491	7792978	0x50318614f9186ab1582214dbecced8412b2e78efa4c03d18ad732c601614fd46	2022-10-19 19:52:38+00
492	7792979	0xaa6d47b68e6e11fc89bde6d5c0658cdfdf65729a803f822c28d7cdebaeb288d5	2022-10-19 19:52:39+00
493	7792980	0x4a5d16129ff46ac49600e54fb01baef045c9e15399a7b0c7f47cc8cb34e9ad37	2022-10-19 19:52:40+00
494	7792981	0xfa1b1db6634429b577ecfde0e05f9d229fe0f0a1bb827d06b35bbaf639b91c7f	2022-10-19 19:52:41+00
495	7792982	0xa5ce4c1b813401c02c1f14bf917012ba4ff714e0f34c56f772623c64f8511732	2022-10-19 19:52:42+00
496	7792983	0xd19b7156879b49a63423ce5fafab32c4ee41a5ffb634d926860008e7d9ca4155	2022-10-19 19:52:43+00
497	7792984	0xc306caa3f203ffa91e15e06698e27a6139e0c404aac74bf1a6f632586590e02c	2022-10-19 19:52:44+00
498	7792985	0xa3a2dfe2878f215054e1c0836dfbcbe82d6f233370542ffcf8785b7d4f04627f	2022-10-19 19:52:45+00
499	7792986	0xfa5c6a33002fa7f833be7bf7e4c078b87d592375d006e80966ae0791f8e63928	2022-10-19 19:52:46+00
500	7792987	0x9f46d8036833285f4e56c77e59c9cb7e7bb10b0a40a7d9eab602c45ba255212c	2022-10-19 19:52:47+00
501	7792988	0xdf69ac4073f05ebc96e71d46172ee7a27f52520b15d6dfab1b67ab8551dfa39e	2022-10-19 19:52:48+00
502	7792989	0xfe8c8d91ba1bf56d75ffd444a1ca076bdd0a85afffa7bdac44f92f86e1c566b2	2022-10-19 19:52:49+00
503	7792990	0x2ee4d96e06940c8ee7fb4a3bf3bce4b2e4c7f1030c58ede1550af1312d9bae90	2022-10-19 19:52:50+00
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
9	MKR_Transformer	504	processing	\N
10	MKR_BalanceTransformer	504	processing	\N
4	raw_log_0x023a960cb9be7ede35b433256f4afe9013334b55_extractor	504	processing	\N
16	Vote_delegate_factory_transformer	504	processing	\N
13	DsChiefTransformer_v1.2	504	processing	\N
1	raw_log_0xdbe5d00b2d8c13a77fb03ee50c87317dbc1b15fb_extractor	504	processing	\N
6	raw_log_0x1a7c1ee5ee2a3b67778ff1ea8c719a3fa1b02b6f_extractor	504	processing	\N
12	ESMV2Transformer	504	processing	\N
3	raw_log_0x105bf37e7d81917b6feacd6171335b4838e53d5e_extractor	504	processing	\N
14	ChiefBalanceTransformer_v1.2	504	processing	\N
11	ESMTransformer	504	processing	\N
7	raw_log_0xe2d249ae3c156b132c40d07bd4d34e73c1712947_extractor	504	processing	\N
8	Polling_Transformer	504	processing	\N
2	raw_log_0xc5e4eab513a7cd12b2335e8a0d57273e13d499f7_extractor	504	processing	\N
5	raw_log_0x33ed584fc655b08b2bca45e1c5b5f07c98053bc1_extractor	504	processing	\N
15	Vote_proxy_factory_transformer_v1.2	504	processing	\N
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
1	734893	0xe7c8fa11a545c51e9756a9b51f3c43f6484bce53ef4b8aaa45a3d0e3b2f79f4d	2022-10-18 18:54:01+00
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
1	raw_log_0x4d196378e636d22766d6a9c6c6f4f32ad3ecb050_extractor	1	processing	\N
2	Arbitrum_Polling_Transformer	1	processing	\N
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

SELECT pg_catalog.setval('vulcan2x.block_id_seq', 504, true);


--
-- Name: job_id_seq; Type: SEQUENCE SET; Schema: vulcan2x; Owner: user
--

SELECT pg_catalog.setval('vulcan2x.job_id_seq', 16, true);


--
-- Name: transaction_id_seq; Type: SEQUENCE SET; Schema: vulcan2x; Owner: user
--

SELECT pg_catalog.setval('vulcan2x.transaction_id_seq', 1, false);


--
-- Name: block_id_seq; Type: SEQUENCE SET; Schema: vulcan2xarbitrum; Owner: user
--

SELECT pg_catalog.setval('vulcan2xarbitrum.block_id_seq', 1, true);


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

