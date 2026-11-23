-- ---------------------------------------------------------------------------
-- 077  Let a payment proof name the billing month it settles
-- ---------------------------------------------------------------------------
-- `handle_payment_proof_approval()` dated every contribution with
-- `to_char(new.payment_date, 'YYYY-MM')` — the month the money arrived. A member
-- paying December's contribution in November therefore got a second November
-- row: they were charged twice for a month already settled and December still
-- showed as owed, so the advance payment cleared nothing.
--
-- The chosen month now travels in `payment_proofs.metadata.target_month`. The
-- trigger honours it when it is a valid 'YYYY-MM' and falls back to the payment
-- date otherwise, so every existing caller keeps working unchanged.
--
-- Validation is deliberately narrow (format only). Whether a month is in the
-- future, how far ahead a member may pay, and whether it is already paid are
-- business rules that live in `backend/src/lib/billingMonth.js` and are enforced
-- at the API. The trigger must stay correct for an admin approving a back-dated
-- manual deposit, which the API never sees.
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
      end;

      begin
        update public.savings set total_saved = total_saved + new.amount,
               last_savings_date = now() where profile_id = new.profile_id;
      exception when others then null; end;
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

    -- Wallet top-up transaction (best-effort)
    if new.payment_type in ('monthly_contribution', 'investment', 'other') then
      begin
        insert into public.transactions (
          profile_id, type, category, amount, description, reference, status
        ) values (
          new.profile_id, 'credit', 'payment_proof', new.amount,
          case new.payment_type
            when 'monthly_contribution' then 'Monthly Contribution via Payment Proof'
            when 'investment' then 'Investment via Payment Proof'
            else 'Payment via Proof'
          end,
          new.transaction_reference, 'successful'
        );
      exception when others then null; end;
    end if;

    -- NEW: post the ledger entry (append-only, source of truth). Money received
    -- is always a credit; the type/allocation describe what the payment
    -- satisfies. `allocation` extends this further into per-obligation splits.
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
        (select loan_id from public.loan_repayments where reference = new.id limit 1),
        new.id, '{}'::jsonb,
        new.approved_by
      );
    exception when others then
      null; -- ledger post must never fail the approval itself
    end;
  end if;
  return new;
end;
$function$;

-- Members query their own contributions by month when the app renders the
-- advance-payment offer, so this lookup must not be a sequential scan.
CREATE INDEX IF NOT EXISTS idx_contributions_profile_month
  ON public.contributions (profile_id, contribution_month);
