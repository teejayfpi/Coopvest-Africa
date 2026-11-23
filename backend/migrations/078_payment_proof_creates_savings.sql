-- ---------------------------------------------------------------------------
-- 078  Approving a payment proof must credit a member who has no savings row
-- ---------------------------------------------------------------------------
-- `handle_payment_proof_approval()` credited savings with a bare
--
--   update public.savings set total_saved = total_saved + new.amount
--    where profile_id = new.profile_id;
--
-- A member who has never opened the Savings screen has no row in `savings` yet
-- — the API creates it lazily on first read. For those members the update
-- matched zero rows, credited nothing, and raised no error, so the surrounding
-- `exception when others then null` never fired. The result was a contribution
-- recorded as 'successful' with `savings.total_saved` still 0 and no ledger
-- entry: the member had paid, the money showed nowhere.
--
-- The same block also swallowed genuine failures, which is what hid the bug.
-- It now creates the row first (ensure_savings_row, the helper the atomic
-- wallet operations already use) and logs any real failure instead of
-- discarding it.
--
-- Already-affected members are not repaired here: rewriting savings balances is
-- a money movement that needs a human decision. The reconciliation job's new
-- `savings_vs_contributions` check surfaces every such member.
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
        -- A member who has never opened the Savings screen has no row here yet.
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
        (select loan_id from public.loan_repayments where reference = new.id limit 1),
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
