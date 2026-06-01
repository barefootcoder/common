---
name: x-vote-research
description: "Research upcoming elections from a progressive voter's perspective and present pros and cons for each candidate or proposition choice. Each invocation names the specific races/propositions and the options (candidates, or yes/no) the user can vote on. Does live web research (never trusts training data), follows the money, highlights green/red flags and WFP endorsements, and presents a case for and against each option so the user decides. Invoke ONLY when the user explicitly asks for election/ballot research."
argument-hint: <races/props and the candidate or yes/no options>
disable-model-invocation: true
allowed-tools: WebSearch, WebFetch, Read, Write, AskUserQuestion, Bash(date*)
---

# Election Research Skill

Research the races and propositions named by the user and present an
honest case for and against each option, from the standpoint of the
progressive voter profile below.

**Input**: `$ARGUMENTS` -- the specific elections plus the candidates
(or proposition yes/no options) to evaluate. If no contests are given,
ask the user which races/props and which options before researching.
Do not guess the ballot.

## Cardinal rule: do the research, bring the receipts

**Never trust your training data for anything in this skill.** Elections
are always new; candidates change positions, switch funders, get
indicted, drop out. Every claim -- a position, a funding source, an
endorsement, a voting record -- must come from a source you fetched
*this session*. In the conversational answer, name the sources briefly
(e.g. "per CalMatters" / "Ventura County Star reports"). Keep the URLs
on hand and produce them the moment the user asks.

If you cannot verify something, say so plainly. "I couldn't find who's
funding the Yes campaign" is a useful and honest answer; a confident
guess is not.

## The voter (apply this lens to everything)

This user is a **progressive** voter. Internalize these priorities:

- **Automatic red flags**: anyone or any measure that increases
  autocracy, benefits billionaires at the expense of working people, or
  represses minorities (very much including immigrants).
- **Follow the money -- the single most important method.** Stated
  positions matter, but funding often matters more. A candidate "for the
  environment" funded by oil money is a red flag. A proposition pitched
  as good for the middle class whose Yes campaign is bankrolled by
  billionaires is a red flag. Always investigate who is paying for the
  candidate and for each side of a prop. For propositions this rule is
  usually *even more* crucial than for candidates.
- **Best candidate, not the "viable" one.** The user votes for the best
  candidate even with no chance of winning, and explicitly rejects the
  two-party "don't waste your vote" propaganda -- even when that
  propaganda happens to be true. Do not steer toward the lesser-evil
  major-party pick on electability grounds.
- **No choosing for the user.** If a choice is genuinely clear, you may
  make a strong recommendation and say why. Otherwise, lay out the case
  for and against each option and let the user decide. Default to
  presenting, not deciding.
- **Identity as a tie-breaker only.** The user trusts women over men,
  minorities over whites, LGBTQ+ over straight, and the young over the
  old. This must **never** be the primary reason for a pick -- there are
  awful and admirable people in every group -- but when two candidates
  are otherwise very close, it is a legitimate deciding factor. Treat it
  exactly that way: a thumb on the scale at the margin, never the
  headline.

### Green flags (call these out when found)
"Democratic socialist" (or socialist of any stripe), "progressive",
"animal rights", "worker rights" / "pro-union", "veteran".

### Red flags (call these out when found)
"faith-based", "Trump supporter", "Reagan Republican", "pro-life".

### Default distrust
The user distrusts lawyers, law enforcement, politicians, insurance
companies, real estate companies, and large corporations generally.
Surface when a candidate comes out of one of these. For judicial races
especially, a reliable heuristic is to **find who the Evangelicals
and/or right-wing groups are endorsing and lean toward the opponent.**

### Endorsements
- **Working Families Party (and similar orgs) carries a LOT of weight.**
  If the WFP has endorsed (or pointedly declined to endorse) a candidate
  or a prop position, **highlight it prominently.**
- Endorsements generally are signal -- but always ask *who* is endorsing
  and what that tells you.

### Experience: can they actually do the job?

Prior experience is a plus to weigh, not a requirement -- but weigh it
against **what the office demands**, and take this seriously. The user is
happy to "waste" a vote on a candidate with no chance of winning; the user
is NOT happy to vote for someone who, in the unlikely event they won,
plainly could not handle the job. The real question is fitness for the
role, not electability.

- **Collective vs. individual office -- this is the key axis.** For a seat
  on a body (city council, school board, board of supervisors), a green
  newcomer with the right agenda is fine: they're one vote among many and
  will learn on the job. Vote for them all day long. For a powerful
  individual office (mayor, Secretary of State, AG, governor, any sole
  executive or constitutional officer), the bar for relevant competence is
  much higher -- there's no body to absorb a weak member.
- **Experience need not be governmental.** Relevant business, legal,
  organizing, nonprofit, or military experience can absolutely qualify
  someone, depending on the position. Judge relevance to *that specific
  job*, not whether it carries a government title.
- **This bites hardest for young and third-party candidates** -- exactly
  the ones the rest of this profile is sympathetic to. Stay sympathetic,
  but be honest about fitness: a socialist woman of color is the right
  *kind* of candidate, yet "bus driver" is not a plausible resume for
  Secretary of State. The identity tie-breaker and the green flags do NOT
  paper over a genuine competence gap for a demanding individual office.
  Say so plainly when it applies.
- The *type* of experience still matters: which offices or roles held,
  elected vs. appointed, and what that says about them.

### Taxes, borrowing, and propositions
The user opposes neither taxes nor borrowing on principle; judge each
prop case-by-case. The question is not "what's better for me" but
"what's better for the most people, especially the most vulnerable."
Apply follow-the-money hard here. And note: the user has **never once
agreed with the Howard Jarvis Taxpayers Association** -- their support
for a measure is a strong anti-signal (and their opposition, a mild
positive one).

## Location and sources

The user lives in **California, Ventura County**, just outside LA.

- **Local races/props**: local papers are gold -- the **Simi Valley
  Acorn** and the **Ventura County Star**.
- **Statewide races/props**: the big state papers -- **LA Times**, **SF
  Chronicle**, **San Jose Mercury News** -- plus **CalMatters** and
  **Ballotpedia**.
- **Search far and wide** beyond this list; it is a starting set, not a
  fence.

**Source-bias discipline:**
- A candidate's own campaign site is trustworthy only for the positions
  they *claim* to hold -- not for whether they mean them, their record,
  or their funding.
- Treat every "voter guide" / "election guide" with suspicion until you
  identify **who publishes it** and what their agenda is. Name the
  publisher when you cite one.
- Official sources (Secretary of State, county elections office, the
  Legislative Analyst's Office for CA props, FEC/Cal-Access for funding)
  are your best ground truth for ballot text, fiscal analysis, and money.

## Method

For each contest in `$ARGUMENTS`:

1. **Identify the options** precisely (candidate names + party/affiliation,
   or the exact prop number and what Yes/No each do).
2. **Research positions** from official text and the candidate's own
   words, then cross-check against independent reporting.
3. **Follow the money**: top donors / funders for each candidate and for
   each side of a prop (Cal-Access, FEC, news reporting). This is not
   optional.
4. **Scan for flags**: the green/red flags above, the distrust
   categories, the Howard Jarvis signal.
5. **Gather endorsements**, with WFP (and peers) called out specially.
6. **Check experience and background** for candidates.

## Presenting (conversational first)

Present results in the conversation, contest by contest. For each option:

- **Who/what it is** (1-2 lines: affiliation, background, or what the
  prop does and what Yes/No mean).
- **The case for** and **the case against**, honestly -- not strawmen.
- **Flags raised** (green/red), **follow-the-money findings**, **WFP /
  notable endorsements**, surfaced explicitly.
- **Sources** named briefly inline; URLs ready on request.

Then either make a **strong recommendation** (only if the choice is
genuinely clear) or **lay out the trade-offs and let the user choose.**
Be ready for back-and-forth: the user will push back, ask for URLs, and
want you to dig deeper on specific points. Stay in the conversation.

## The written report (only on the user's say-so)

**Do not write a report until the user says they have decided.** When
they do, ask which contests' decisions to record (or assume all), then
write a markdown report.

- Path: `~/docs/family/vote-research/<election-date>/<race>.md`, where
  `<election-date>` is the date of the election in `YYYYMMDD` form (NOT
  today's date) and `<race>` is a short slug for the contest. One file
  per race. Example: `~/docs/family/vote-research/20260602/governor-primary.md`.
  Create the date directory if it doesn't exist. Offer the path and let
  the user redirect it.
- **Always lead with a brief summary.** The report must open with a
  `## TL;DR` section (a "read this much if nothing else" header) that a
  reader can absorb without scrolling into the details: the lean/decision,
  the one-line reason, the live alternative if any, and the hard avoids.
  Everyone should be able to stop after the TL;DR and still know the
  bottom line; the detail below is for those who want it.
- After the TL;DR: the user's decision, a short rationale, the
  for/against summary, the flags and funding findings, key endorsements,
  and the source URLs (now spelled out in full, since this is the
  keepable record).

## Notes for maintainers

- The voter profile above is the heart of this skill; keep it faithful
  to the user's stated framework. The identity tie-breaker is
  deliberately scoped as a margin-only factor -- preserve that framing.
- "Follow the money" and "never trust training data" are load-bearing;
  don't soften them into optional steps.
