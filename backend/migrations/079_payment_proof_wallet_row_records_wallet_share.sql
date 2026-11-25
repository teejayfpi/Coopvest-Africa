-- ---------------------------------------------------------------------------
-- 079  Record only the wallet-bound share in the proof's wallet transaction
-- ---------------------------------------------------------------------------
-- Approving a payment proof writes a `transactions` row describing money that
-- reached the member's wallet. For a straight `monthly_contribution` the whole
-- amount is savings, so the row is exact. For `other` (fine / fee / mixed) the
-- trigger wrote the GROSS charge:
--
--   other N6,500 = N5,000 savings (wallet) + N1,500 admin fee (income)
--   transactions row: deposit N6,500  <-- N1,500 never reached the wallet
--
-- `wallets.balance` is updated separately by `applyAllocations`, which credits
-- only the savings share. The two disagreed by the fee share, and the
-- `wallet_balance_vs_ledger` integrity check reported it as a CRITICAL
-- discrepancy every six hours on production:
--
--   wallets.balance  = 5000
--   ledger net       = 11500  (6500 deposit + 5000 savings_deposit)
--
-- A wallet row must describe wallet money. The fee share is cooperative income
-- and is already recorded in `member_fees` and `ledger_entries`; a `transactions`
-- row claiming it as a member credit is wrong.
--
-- `savings_deposit` is left as-is: it credits `savings.total_saved`, never the
-- wallet, and is excluded from the wallet comparison by type.

create or replace function public.handle_payment_proof_approval()
returns trigger
language plpgsql
security definer
as $function$
declare
  member_record record;
  receipt_num text;
  new_contribution_id uuid;
  target_month text;
  wallet_amount numeric;
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
    --
    -- The amount is the wallet-bound share, not the gross charge: for `other`
    -- the fee/fine allocations are income and never reach the wallet, so
    -- recording them here claimed member money that does not exist.
    if new.payment_type in ('monthly_contribution', 'investment', 'other') then
      wallet_amount := new.amount;
      if new.payment_type = 'other' then
        select coalesce(sum((a ->> 'amount')::numeric), 0)
          into wallet_amount
          from jsonb_array_elements(
                 case
                   when jsonb_typeof(new.metadata -> 'allocations') = 'array'
                     then new.metadata -> 'allocations'
                   else '[]'::jsonb
                 end
               ) as a
         where a ->> 'type' = 'savings';
      end if;

      if wallet_amount > 0 then
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
            'credit', wallet_amount,
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
