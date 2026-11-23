-- ---------------------------------------------------------------------------
-- 078  Make payment-proof approval actually post the money it records
-- ---------------------------------------------------------------------------
-- Approving a payment proof is supposed to write the contribution, the savings
-- credit, a wallet transaction and the append-only ledger entry. Three separate
-- defects meant none of the money reached the tables, and
-- `exception when others then null` discarded every error:
--
--   1. Savings was credited with a bare `update ... where profile_id = ...`.
--      `savings` is created lazily by the API on first read, so a member who had
--      never opened the Savings screen had no row: the update matched zero rows
--      and credited nothing. A zero-row UPDATE is not an error, so nothing was
--      raised. Confirmed on production - two 5000 contributions approved at
--      05:15 and 05:17 were 'successful' while savings.total_saved stayed 0 and
--      the savings row itself was not created until 15:11.
--
--   2. The wallet transaction insert never supplied `transaction_id`, which is
--      NOT NULL with no default, so it failed every time:
--      'null value in column "transaction_id" of relation "transactions"
--       violates not-null constraint'.
--
--   3. The ledger insert compared `loan_repayments.reference` (text) to
--      `new.id` (uuid) with no cast, so it failed every time:
--      'operator does not exist: text = uuid'.
--
-- The net effect was that `transactions` and `ledger_entries` were both empty
-- for every approval ever made, so no statement or reconciliation could
-- reconstruct what a member had paid.
--
-- Each block now raises a warning carrying the real message instead of
-- swallowing it, so the next failure of this kind appears in the Postgres log
-- rather than silently costing a member their money.
--
-- Existing drift is not rewritten here: crediting savings and back-posting
-- ledger rows is a money movement that needs a human decision. The
-- reconciliation job's `savings_vs_contributions` check names every affected
-- member.
CREATE OR REPLACE FUNCTION public.handle_payment_proof_approval()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  member_record record;
  receipt_num text;
  new_contribution_id uuid;
  target_month text;
begin
  if new.status = 'approved' and old.status != 'approved' then
    select * into member_record from public.profiles where id = new.profile_id;
    receipt_num := public.generate_receipt_number();

    -- The month this payment settles. `metadata.target_month` is set when the
    -- member pays a month in advance; anything else keeps the old behaviour.
    target_month := nullif(trim(new.metadata ->> 'target_month'), '');
    if target_month is null or target_month !~ '^\d{4}-(0[1-9]|1[0-2])$' then
      target_month := to_char(new.payment_date, 'YYYY-MM');
    end if;

    -- Contribution + savings (monthly_contribution only)
    if new.payment_type = 'monthly_contribution' then
      begin
        insert into public.contributions (
          profile_id, amount, status, contribution_month, payment_proof_id, notes
        ) values (
          new.profile_id, new.amount, 'successful',
          target_month,
          new.id, 'Auto-created from payment proof verification'
        ) returning id into new_contribution_id;
        new.contribution_id := new_contribution_id;
      exception when others then
        new_contribution_id := null;
        raise warning 'payment proof %: contribution insert failed: %', new.id, sqlerrm;
      end;

      begin
        -- `savings` is created lazily by the API, so a member paying for the
        -- first time has no row yet and the update below would match nothing.
        perform public.ensure_savings_row(new.profile_id);
        update public.savings
           set total_saved = coalesce(total_saved, 0) + new.amount,
               balance = coalesce(balance, 0) + new.amount,
               last_savings_date = now()
         where profile_id = new.profile_id;
      exception when others then
        raise warning 'payment proof %: savings credit failed: %', new.id, sqlerrm;
      end;
    end if;

    -- Digital receipt
    insert into public.digital_receipts (
      receipt_number, receipt_id, payment_proof_id, profile_id, member_name,
      membership_id, payment_type, amount, currency, transaction_reference,
      payment_date, payment_method, receiving_bank, approved_by, approved_by_name,
      approved_at, organization_name
    ) values (
      receipt_num, 'RCP-' || substring(receipt_num, 4, 8), new.id, new.profile_id,
      member_record.name, member_record.user_id, new.payment_type, new.amount,
      new.currency, new.transaction_reference, new.payment_date, new.payment_method,
      new.receiving_bank, new.approved_by,
      (select name from public.profiles where id = new.approved_by limit 1),
      new.approved_at, 'Coopvest Africa'
    );

    -- Wallet transaction. Three constraints on `transactions` rejected the old
    -- row: `transaction_id` is NOT NULL with no default, `type` must come from a
    -- fixed list, `category` must be 'credit' or 'debit', and `status` must be
    -- one of pending/processing/completed/failed/cancelled/reversed.
    if new.payment_type in ('monthly_contribution', 'investment', 'other') then
      begin
        insert into public.transactions (
          transaction_id, profile_id, type, category, amount, description,
          reference, status, completed_at
        ) values (
          'TXN-' || gen_random_uuid()::text,
          new.profile_id,
          case new.payment_type
            when 'monthly_contribution' then 'savings_deposit'
            when 'investment' then 'investment'
            else 'deposit'
          end,
          'credit', new.amount,
          case new.payment_type
            when 'monthly_contribution' then 'Monthly Contribution via Payment Proof'
            when 'investment' then 'Investment via Payment Proof'
            else 'Payment via Proof'
          end,
          new.transaction_reference, 'completed', now()
        );
      exception when others then
        raise warning 'payment proof %: wallet transaction insert failed: %', new.id, sqlerrm;
      end;
    end if;

    -- Ledger entry (append-only, source of truth). Money received is always a
    -- credit; the type/allocation describe what the payment satisfies.
    begin
      insert into public.ledger_entries (
        profile_id, reference, type, description, debit, credit, source,
        status, initiated_by, approved_by, txn_no, member_name, membership_id,
        payment_method, bank_account, amount, loan_id, payment_proof_id, allocation,
        checked_by
      ) values (
        new.profile_id,
        new.transaction_reference,
        new.payment_type,
        'Auto-posted from verified payment proof',
        0, new.amount, new.amount,
        'payment_proof', new.profile_id, new.approved_by,
        public.next_ledger_txn_no(),
        member_record.name, member_record.user_id,
        new.payment_method, new.receiving_bank, new.amount,
        -- loan_repayments.reference is text; new.id is uuid.
        (select loan_id from public.loan_repayments where reference = new.id::text limit 1),
        new.id, '{}'::jsonb,
        new.approved_by
      );
    exception when others then
      raise warning 'payment proof %: ledger post failed: %', new.id, sqlerrm;
    end;
  end if;
  return new;
end;
$function$;
