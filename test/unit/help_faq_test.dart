import 'package:flutter_test/flutter_test.dart';
import 'package:coopvest_mobile/core/content/help_faq.dart';

/// The help centre exists so a member can get an answer without waiting for a
/// person. These tests protect the two ways it could betray that: answering
/// with nothing when a real question was asked, and answering with the wrong
/// article — which is worse than no answer, because it looks authoritative.
void main() {
  group('the content is complete', () {
    test('every entry has a question and an answer', () {
      for (final entry in helpEntries) {
        expect(entry.question.trim(), isNotEmpty, reason: '${entry.id} has no question');
        expect(entry.answer.trim(), isNotEmpty, reason: '${entry.id} has no answer');
      }
    });

    test('entry ids are unique', () {
      final ids = helpEntries.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate id would shadow an entry');
    });

    test('every category has at least one answer', () {
      // A category tile that opens onto an empty list looks broken.
      for (final category in HelpCategory.values) {
        expect(helpByCategory(category), isNotEmpty,
            reason: '${category.label} has no entries');
      }
    });

    test('answers are long enough to actually help', () {
      for (final entry in helpEntries) {
        expect(entry.answer.length, greaterThan(80),
            reason: '${entry.id} is too terse to resolve anything');
      }
    });

    test('category ticket values are real ticket categories', () {
      // These are the values the backend's tickets.category CHECK accepts.
      // A wrong one makes "still need help" fail at submit time.
      const valid = {
        'loan_issue', 'guarantor_consent', 'referral_bonus', 'repayment_issue',
        'account_kyc', 'contribution', 'withdrawal', 'technical_bug',
        'complaint', 'other',
      };
      for (final category in HelpCategory.values) {
        expect(valid, contains(category.ticketCategory),
            reason: '${category.label} maps to an unknown ticket category');
      }
    });
  });

  group('search finds the right article', () {
    /// The top hit for a query, or null.
    HelpEntry? topHit(String query) {
      final results = searchHelp(query);
      return results.isEmpty ? null : results.first;
    }

    test('a member asking about withdrawals gets the withdrawal answer', () {
      expect(topHit('withdraw')?.category, HelpCategory.withdrawal);
      expect(topHit('money not arrived')?.category, HelpCategory.withdrawal);
      expect(topHit('payout delay')?.category, HelpCategory.withdrawal);
    });

    test('a member asking about loan eligibility gets the eligibility answer', () {
      expect(topHit('loan eligible')?.id, 'loan-eligibility');
      expect(topHit('why cant i get a loan')?.category, HelpCategory.loan);
      expect(topHit('qualify')?.id, 'loan-eligibility');
    });

    test('a member asking about interest gets the interest answer', () {
      expect(topHit('interest')?.id, 'loan-interest');
      expect(topHit('how is interest calculated')?.id, 'loan-interest');
    });

    test('a member asking about a guarantor gets a guarantor answer', () {
      expect(topHit('guarantor')?.category, HelpCategory.guarantor);
      expect(topHit('someone asked me to guarantee')?.category, HelpCategory.guarantor);
    });

    test('a member asking about BVN gets the KYC answer', () {
      expect(topHit('bvn')?.category, HelpCategory.kyc);
      expect(topHit('why do you need my id')?.category, HelpCategory.kyc);
    });

    test('a member asking about referral bonus gets the referral answer', () {
      expect(topHit('referral bonus')?.id, 'referral-how-it-works');
      expect(topHit('invite friends')?.category, HelpCategory.referral);
    });

    test('a member asking why a contribution is pending gets that answer', () {
      expect(topHit('contribution pending')?.id, 'contribution-marked-pending');
    });

    test('a member who cannot log in gets the login answer', () {
      expect(topHit('cannot log in')?.id, 'app-cannot-login');
      expect(topHit('forgot password')?.id, 'app-cannot-login');
    });

    test('search is case and punctuation insensitive', () {
      final a = searchHelp('WITHDRAWAL').map((e) => e.id).toList();
      final b = searchHelp('withdrawal?').map((e) => e.id).toList();
      final c = searchHelp('  withdrawal  ').map((e) => e.id).toList();
      expect(a, b);
      expect(b, c);
    });

    test('a noun finds the article that uses its verb form', () {
      // Regression: "withdrawal" did not surface "How do I withdraw money from
      // my wallet?", because "withdraw" and "withdrawal" share no exact form.
      // The most relevant article was missing from its own topic's search.
      final ids = searchHelp('withdrawal').map((e) => e.id).toList();
      expect(ids, contains('withdrawal-how'));

      final repay = searchHelp('repayment').map((e) => e.id).toList();
      expect(repay, contains('repayment-early'));

      final contribute = searchHelp('contribution').map((e) => e.id).toList();
      expect(contribute, contains('contribution-amount'));
    });

    test('plurals match their singular article', () {
      // Members type "loans" and "withdrawals". Before stemming, these
      // returned nothing, which reads as "the app has no answer".
      expect(searchHelp('loans'), isNotEmpty);
      expect(searchHelp('withdrawals'), isNotEmpty);
      expect(searchHelp('contributions'), isNotEmpty);
      expect(searchHelp('referrals'), isNotEmpty);
      expect(searchHelp('loans').first.category, HelpCategory.loan);
    });

    test('a partial word still matches', () {
      // Members type "eligib" and stop. Prefix matching covers that.
      expect(searchHelp('eligib'), isNotEmpty);
    });
  });

  group('search refuses to invent an answer', () {
    test('an empty query returns nothing', () {
      expect(searchHelp(''), isEmpty);
      expect(searchHelp('   '), isEmpty);
    });

    test('only stop words returns nothing rather than everything', () {
      // Returning the whole list here would look like a match and mislead.
      expect(searchHelp('how do i'), isEmpty);
      expect(searchHelp('what is the'), isEmpty);
    });

    test('a question nothing covers returns nothing', () {
      // Better an empty result and a "contact support" button than a wrong
      // article presented as the answer.
      expect(searchHelp('cryptocurrency staking'), isEmpty);
      expect(searchHelp('mortgage rates in london'), isEmpty);
    });
  });

  group('search ranks sensibly', () {
    test('a question-word match outranks an answer-body mention', () {
      final results = searchHelp('withdrawal');
      expect(results, isNotEmpty);
      // Withdrawal articles must come before anything that merely mentions
      // withdrawals in passing.
      expect(results.first.category, HelpCategory.withdrawal);
    });

    test('results are ordered by score, highest first', () {
      final results = searchHelp('loan');
      expect(results.length, greaterThan(1));
      expect(results.first.category, HelpCategory.loan);
    });

    test('the same query returns a stable order', () {
      final a = searchHelp('loan repayment').map((e) => e.id).toList();
      final b = searchHelp('loan repayment').map((e) => e.id).toList();
      expect(a, b);
    });
  });
}
