/// Member-facing help content.
///
/// Every answer is traceable to the code that enforces it: the loan rules in
/// `contributionConsistency.js` / `loanPolicy.js`, the referral tiers in
/// `referralService.js`, the withdrawal and guarantor routes, and the
/// contribution status list in `contributionStatuses.js`. Nothing here is
/// invented.
///
/// Two deliberate omissions:
///
///  * **No money amounts.** Registration and administrative fees live in the
///    database (`member_fees`, `fee_schedule`), not in code, so any figure
///    written here could disagree with what a member is actually billed. Copy
///    points at the screen that shows the live number instead.
///  * **No eligibility verdicts.** The server decides eligibility; a help
///    article that guessed would contradict `assessEligibility()`.
library;

/// The support-ticket categories, reused so help content, tickets and the
/// admin portal all speak the same vocabulary.
enum HelpCategory {
  contribution('contribution', 'Savings and Contributions'),
  loan('loan_issue', 'Loans'),
  repayment('repayment_issue', 'Repayments'),
  guarantor('guarantor_consent', 'Guarantors'),
  withdrawal('withdrawal', 'Withdrawals'),
  referral('referral_bonus', 'Referrals'),
  kyc('account_kyc', 'Account and KYC'),
  technical('technical_bug', 'App Problems');

  const HelpCategory(this.ticketCategory, this.label);

  /// The `tickets.category` value this maps to, for "still need help".
  final String ticketCategory;
  final String label;
}

class HelpEntry {
  const HelpEntry({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.keywords = const [],
  });

  final String id;
  final HelpCategory category;
  final String question;
  final String answer;

  /// Extra words a member might type that do not appear in the question.
  final List<String> keywords;
}

/// Answers ordered by how often members ask them.
const List<HelpEntry> helpEntries = [
  HelpEntry(
    id: 'contribution-marked-pending',
    category: HelpCategory.contribution,
    question: 'Why is my contribution still showing as pending?',
    answer: 'A contribution counts as paid once the payment has settled. If you '
        'paid through Paystack it normally settles within minutes. A bank '
        'transfer you uploaded a receipt for waits until our team approves it.',
    keywords: ['pending', 'not showing', 'unpaid', 'settle', 'receipt'],
  ),
  HelpEntry(
    id: 'contribution-status-words',
    category: HelpCategory.contribution,
    question: 'My contribution says "completed" but my friend says "successful". '
        'Is something wrong?',
    answer: 'No. The system records a settled payment as successful, completed, '
        'approved or paid, depending on how it arrived. All four mean the money '
        'reached your savings.',
    keywords: ['successful', 'completed', 'approved', 'paid', 'status'],
  ),
  HelpEntry(
    id: 'contribution-amount',
    category: HelpCategory.contribution,
    question: 'How much am I meant to contribute each month?',
    answer: 'Your monthly amount is set when you join and shown on the Savings '
        'card on your Home screen. If you believe it is wrong, raise it with '
        'support rather than changing it yourself. It is what your loan '
        'eligibility is measured against.',
    keywords: ['monthly', 'amount', 'how much', 'savings', 'contribution'],
  ),
  HelpEntry(
    id: 'contribution-missed-month',
    category: HelpCategory.contribution,
    question: 'I missed a month. Can I catch up?',
    answer: 'Yes. Pay the missed month through the Obligations card on your Home '
        'screen. Be aware that loan eligibility looks for consecutive months, so '
        'a missed month interrupts the run even after you pay it.',
    keywords: ['missed', 'skip', 'catch up', 'arrears', 'behind', 'late'],
  ),
  HelpEntry(
    id: 'loan-eligibility',
    category: HelpCategory.loan,
    question: 'Why am I not eligible for a loan yet?',
    answer: 'A new loan needs six months of membership and six consecutive '
        'months of contributions with no month missed, and your contributions '
        'must be up to date when you apply. Paying a missed month restores the '
        'balance but does not repair the run of consecutive months.',
    keywords: ['eligible', 'eligibility', 'cannot apply', 'rejected', 'six months', 'qualify'],
  ),
  HelpEntry(
    id: 'loan-interest',
    category: HelpCategory.loan,
    question: 'How is the interest on my loan calculated?',
    answer: 'Interest is simple, not compounded. The total you repay is the '
        'amount you borrowed plus that amount multiplied by the rate. Your '
        'monthly repayment is that total divided by the number of months, so the '
        'instalments always add up to exactly the total shown.',
    keywords: ['interest', 'rate', 'calculation', 'simple', 'monthly repayment', 'total'],
  ),
  HelpEntry(
    id: 'loan-tenure',
    category: HelpCategory.loan,
    question: 'Can I choose any repayment period?',
    answer: 'Each loan product has a fixed repayment period. For example a Quick '
        'Loan runs a shorter term than a Maxi Loan. The application form shows '
        'the period for the product you pick, and the period is what decides '
        'your monthly repayment.',
    keywords: ['tenure', 'duration', 'months', 'period', 'how long', 'repayment plan'],
  ),
  HelpEntry(
    id: 'loan-amount-received',
    category: HelpCategory.loan,
    question: 'Why did I receive less than I applied for?',
    answer: 'Check the loan breakdown in the app. It shows the amount approved '
        'and any deductions applied before disbursement. If a figure there does '
        'not match what you expected, open a ticket and we will walk through it '
        'with you.',
    keywords: ['less', 'deduction', 'shortfall', 'disbursed', 'received', 'amount'],
  ),
  HelpEntry(
    id: 'repayment-not-reflecting',
    category: HelpCategory.repayment,
    question: 'I repaid my loan but the balance has not gone down.',
    answer: 'A repayment updates your balance when it is confirmed. For a bank '
        'transfer that means after our team approves the receipt. If it has been '
        'more than two business days, open a ticket with the payment reference '
        'and we will trace it.',
    keywords: ['repaid', 'balance', 'not updated', 'loan balance', 'still owing', 'repayment'],
  ),
  HelpEntry(
    id: 'repayment-early',
    category: HelpCategory.repayment,
    question: 'Can I pay off my loan early?',
    answer: 'Yes. You can pay more than the monthly instalment, or clear the '
        'whole outstanding balance at once. Your remaining balance is reduced by '
        'whatever you pay.',
    keywords: ['early', 'pay off', 'settle', 'clear', 'lump sum', 'overpay', 'repayment'],
  ),
  HelpEntry(
    id: 'repayment-due-date',
    category: HelpCategory.repayment,
    question: 'When is my repayment due?',
    answer: 'Your due date is shown on the loan details screen, alongside the '
        'monthly amount. The Obligations card on your Home screen also lists '
        'anything currently due.',
    keywords: ['due', 'date', 'when', 'deadline', 'monthly', 'instalment'],
  ),
  HelpEntry(
    id: 'guarantor-what-is-it',
    category: HelpCategory.guarantor,
    question: 'What does a guarantor have to do?',
    answer: 'A guarantor agrees to stand behind your loan. We send them a '
        'request in the app and they accept or decline it. Your loan moves to '
        'review once the number of guarantors required for that product have '
        'accepted.',
    keywords: ['guarantor', 'guarantee', 'stand for me', 'request', 'consent'],
  ),
  HelpEntry(
    id: 'guarantor-declined',
    category: HelpCategory.guarantor,
    question: 'My guarantor declined. What happens now?',
    answer: 'Nothing is lost. Your application stays open, and you can nominate '
        'a different guarantor from the loan screen. We let you know as soon as '
        'someone accepts or declines.',
    keywords: ['declined', 'rejected', 'refused', 'guarantor', 'replace', 'another'],
  ),
  HelpEntry(
    id: 'guarantor-i-was-asked',
    category: HelpCategory.guarantor,
    question: 'Someone asked me to be their guarantor. What am I agreeing to?',
    answer: 'You are agreeing to be contacted if that member stops repaying. You '
        'can accept or decline the request from your notifications, and you can '
        'withdraw your consent afterwards. Only guarantee a loan you are willing '
        'to stand behind.',
    keywords: ['asked me', 'guarantor request', 'should i', 'accept', 'decline', 'risk'],
  ),
  HelpEntry(
    id: 'withdrawal-how',
    category: HelpCategory.withdrawal,
    question: 'How do I withdraw money from my wallet?',
    answer: 'Open the Wallet tab and start a withdrawal to your bank account. '
        'You can withdraw up to your available balance. A withdrawal is reviewed '
        'before it is paid out, so the money leaves your balance once it is '
        'approved.',
    keywords: ['withdraw', 'withdrawal', 'cash out', 'bank', 'transfer', 'payout', 'wallet'],
  ),
  HelpEntry(
    id: 'withdrawal-one-at-a-time',
    category: HelpCategory.withdrawal,
    question: 'Why can I only have one withdrawal at a time?',
    answer: 'Only one withdrawal can be awaiting approval at once. This stops a '
        'member from requesting the same money twice while the first request is '
        'still being processed. Wait for the current one to be approved or '
        'declined, then request again.',
    keywords: ['one at a time', 'already have', 'pending', 'second', 'another withdrawal'],
  ),
  HelpEntry(
    id: 'withdrawal-delay',
    category: HelpCategory.withdrawal,
    question: 'My withdrawal has not arrived. How long does it take?',
    answer: 'Withdrawals are checked by our team before payout, so they are not '
        'instant. If yours has been waiting longer than you expected, open a '
        'ticket with the date and amount and we will check where it is.',
    keywords: ['delay', 'not arrived', 'slow', 'how long', 'waiting', 'stuck'],
  ),
  HelpEntry(
    id: 'referral-how-it-works',
    category: HelpCategory.referral,
    question: 'How does the referral bonus work?',
    answer: 'You earn an interest discount on your own loans as more of the '
        'people you referred become confirmed. Two confirmed referrals earns a '
        'small discount, five a larger one, and ten the maximum. The discount '
        'reduces the rate you pay, and it never takes the rate below half of the '
        'normal rate for that product.',
    keywords: ['referral', 'bonus', 'invite', 'discount', 'tier', 'reward'],
  ),
  HelpEntry(
    id: 'referral-not-confirmed',
    category: HelpCategory.referral,
    question: 'My referral is not counting. Why?',
    answer: 'A referral is confirmed only after a 30 day lock-in has passed and '
        'the person you referred has met the qualification criteria, including '
        'at least three months of savings. Until both are true it stays pending, '
        'which is why it may not appear in your count yet.',
    keywords: ['not counting', 'pending', 'referral', 'not confirmed', 'waiting', 'lock-in'],
  ),
  HelpEntry(
    id: 'referral-share',
    category: HelpCategory.referral,
    question: 'Where do I find my referral code?',
    answer: 'The referral dashboard shows your code and lets you share it '
        'directly. Your referrals need to sign up with that code for the '
        'referral to be linked to you.',
    keywords: ['code', 'link', 'share', 'invite friends', 'referral dashboard'],
  ),
  HelpEntry(
    id: 'kyc-why',
    category: HelpCategory.kyc,
    question: 'Why do you need my BVN and ID?',
    answer: 'We are required to verify who our members are before they save or '
        'borrow. Your BVN and identity details are used only for that check. '
        'Never send your BVN in a chat message or email. Enter it in the '
        'verification screen only.',
    keywords: ['bvn', 'nin', 'id', 'why', 'verification', 'identity', 'privacy'],
  ),
  HelpEntry(
    id: 'kyc-pending',
    category: HelpCategory.kyc,
    question: 'My verification is still pending. What now?',
    answer: 'Verification is reviewed by a person, so it is not instant. If it '
        'has been pending for more than a few business days, open a ticket. '
        'Sometimes a document is unclear and needs to be submitted again.',
    keywords: ['kyc', 'verification', 'pending', 'not approved', 'stuck', 'review'],
  ),
  HelpEntry(
    id: 'kyc-rejected',
    category: HelpCategory.kyc,
    question: 'My verification was rejected. Can I try again?',
    answer: 'Yes. Open a ticket and tell us what was rejected. Usually it is a '
        'blurred document or a name that does not match. Once corrected you can '
        'resubmit.',
    keywords: ['rejected', 'kyc', 'failed', 'retry', 'resubmit', 'declined'],
  ),
  HelpEntry(
    id: 'kyc-age',
    category: HelpCategory.kyc,
    question: 'How old do I have to be to join?',
    answer: 'You must be at least 18. Registration checks your date of birth and '
        'will not accept anyone younger.',
    keywords: ['age', '18', 'old', 'minimum age', 'birthday'],
  ),
  HelpEntry(
    id: 'app-cannot-login',
    category: HelpCategory.technical,
    question: 'I cannot log in.',
    answer: 'Check you are using the email you registered with, then try '
        'resetting your password from the login screen. If a code or link has '
        'expired, request a new one. They are time limited.',
    keywords: ['login', 'cannot log in', 'password', 'locked out', 'reset', 'otp'],
  ),
  HelpEntry(
    id: 'app-blank-screen',
    category: HelpCategory.technical,
    question: 'A screen is blank or will not load.',
    answer: 'Close and reopen the app first. If it persists, check your internet '
        'connection and try again, because a weak connection can leave a screen '
        'waiting on data. If it still happens, open a ticket and tell us which '
        'screen.',
    keywords: ['blank', 'not loading', 'stuck', 'white screen', 'error', 'crash'],
  ),
  HelpEntry(
    id: 'app-notifications',
    category: HelpCategory.technical,
    question: 'I am not getting notifications.',
    answer: 'Check that notifications are allowed for the app in your phone '
        'settings. Many phones turn them off after an update. In-app '
        'notifications still appear in the bell icon even when push is off.',
    keywords: ['notification', 'push', 'alerts', 'not receiving', 'bell'],
  ),
];

/// Words too common to signal what a member is asking about.
const Set<String> _stopWords = {
  'i', 'a', 'an', 'the', 'is', 'are', 'am', 'was', 'were', 'be', 'been', 'do',
  'does', 'did', 'my', 'me', 'we', 'you', 'your', 'it', 'its', 'to', 'of', 'in',
  'on', 'at', 'for', 'with', 'and', 'or', 'but', 'not', 'no', 'can', 'could',
  'should', 'would', 'will', 'what', 'why', 'how', 'when', 'where', 'who',
  'have', 'has', 'had', 'get', 'got', 'this', 'that', 'there', 'from', 'about',
  'if', 'so', 'just', 'still', 'any', 'all', 'please', 'help', 'need', 'want',
};

String _normalise(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');

Set<String> _tokenise(String s) => _normalise(s)
    .split(RegExp(r'\s+'))
    .where((w) => w.length > 1 && !_stopWords.contains(w))
    .toSet();

/// Reduces a word to a comparison stem so "loans" matches "loan" and
/// "withdrawals" matches "withdrawal". Members type plurals; without this a
/// search for "loans" returns nothing, which reads as "the app has no answer".
String _stem(String w) {
  if (w.length > 4 && w.endsWith('ies')) return '${w.substring(0, w.length - 3)}y';
  if (w.length > 3 && w.endsWith('es')) return w.substring(0, w.length - 2);
  if (w.length > 3 && w.endsWith('s') && !w.endsWith('ss')) {
    return w.substring(0, w.length - 1);
  }
  return w;
}

/// Are [a] and [b] the same word in different forms?
///
/// Members type "withdrawal" where the article says "withdraw", and
/// "contribution" where it says "contribute". Neither is a prefix of the other,
/// so a plain `startsWith` check misses them, which silently dropped the most
/// relevant article from its own topic.
///
/// The shared stem must be long and must cover most of the longer word, or
/// unrelated words match on a short prefix: "payout" and "pay" share only
/// three letters, and treating those as equal ranked "Can I pay off my loan
/// early?" above the withdrawal article for the query "payout delay".
bool _similar(String a, String b) {
  if (a == b) return true;
  final minLen = a.length < b.length ? a.length : b.length;
  if (minLen < 4) return false;
  var shared = 0;
  while (shared < minLen && a.codeUnitAt(shared) == b.codeUnitAt(shared)) {
    shared++;
  }
  final maxLen = a.length > b.length ? a.length : b.length;
  return shared >= 6 && shared / maxLen >= 0.7;
}

bool _matchesAny(String token, Set<String> words) =>
    words.any((w) => _similar(token, w));

/// Ranks [helpEntries] against what the member typed.
///
/// Deliberately simple and offline: no network, no model, nothing to fail.
///
/// Ranking is by how many query words matched, then by where they matched —
/// question, then keywords, then answer. Two rules keep it honest:
///
///  * **A majority of query words must match**, so "mortgage rates in london"
///    does not resolve to the loan-interest article on the word "rate" alone.
///  * **At least one word must match the question or keywords**, not only the
///    answer body. Matching prose alone is too weak: "money not arrived"
///    surfaced the contribution-status article because both words appear
///    somewhere in its answer, outranking the withdrawal article that names
///    arrival in its question.
List<HelpEntry> searchHelp(String query, {List<HelpEntry> entries = helpEntries}) {
  final tokens = _tokenise(query).map(_stem).toSet();
  if (tokens.isEmpty) return const [];

  final requiredMatches = (tokens.length / 2).ceil();
  final scored = <(int, int, int, HelpEntry)>[];

  for (final entry in entries) {
    final questionWords = _tokenise(entry.question).map(_stem).toSet();
    final keywordWords = _tokenise(entry.keywords.join(' ')).map(_stem).toSet();
    final answerWords = _tokenise(entry.answer).map(_stem).toSet();

    var strong = 0;
    var matched = 0;
    var score = 0;
    for (final token in tokens) {
      if (_matchesAny(token, questionWords)) {
        strong++;
        matched++;
        score += 10;
      } else if (_matchesAny(token, keywordWords)) {
        strong++;
        matched++;
        score += 6;
      } else if (_matchesAny(token, answerWords)) {
        matched++;
        score += 2;
      }
    }
    if (strong > 0 && matched >= requiredMatches) {
      scored.add((matched, strong, score, entry));
    }
  }

  scored.sort((a, b) {
    final byMatched = b.$1.compareTo(a.$1);
    if (byMatched != 0) return byMatched;
    final byStrong = b.$2.compareTo(a.$2);
    if (byStrong != 0) return byStrong;
    final byScore = b.$3.compareTo(a.$3);
    return byScore != 0 ? byScore : a.$4.id.compareTo(b.$4.id);
  });
  return scored.map((e) => e.$4).toList();
}

/// Entries in one category, in the order they are declared.
List<HelpEntry> helpByCategory(HelpCategory category,
        {List<HelpEntry> entries = helpEntries}) =>
    entries.where((e) => e.category == category).toList();
