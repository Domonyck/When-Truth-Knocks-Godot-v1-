extends Node
# Autoload this as "Story" (Project Settings > Autoload).
#
# Scope note: this file only covers the STORY DATA + TYPING GAME half of
# the loop below. The door-knock/NPC-appearance/bulletin-puzzle parts are
# someone else's systems — this file just exposes what they need to call.
#
#   Door knocks -> NPC shows up -> shares 1 of 3 possible testimonies
#     -> [OUT OF SCOPE] if true: unlock that case's bulletin level
#     -> [OUT OF SCOPE] if false: try again (re-knock, re-draw)
#     -> [OUT OF SCOPE] bulletin board puzzle
#     -> on puzzle success: Monkeytype game types that case's manuscript
#
# It's all ONE article, assembled in order. "intro" is just the first
# entry in that sequence — unlocked from the start, no testimony needed,
# so the player has something to type before any interviews happen. The 3
# real cases (case1-3) unlock the normal way and get appended after it.

signal case_unlocked(case_id: String)
signal case_completed(case_id: String)

const INTRO_ID := "intro"

class Testimony:
	var text: String = ""
	var is_true: bool = false

class CaseData:
	var id: String
	var testimonies: Array[Testimony] = []   # exactly 3, order shuffled ([] for intro)
	var manuscript_text: String = ""
	var unlocked: bool = false   # true once the true testimony has been heard
	var solved: bool = false     # true once the manuscript has been typed
	var progress_word_index: int = 0    # how many words are confirmed done
	var progress_typed_text: String = ""   # partial characters of the current word

var cases: Dictionary = {}          # id -> CaseData
var order: Array[String] = [INTRO_ID, "case1", "case2", "case3"]   # article assembly order
var interview_cases: Array[String] = ["case1", "case2", "case3"]   # the ones that gate is_run_complete()

func _ready() -> void:
	randomize()
	new_game()

func new_game() -> void:
	cases.clear()

	_build_case(INTRO_ID, [],
		"Three weeks in this city and the cases were still routine work: unpaid invoices, wandering house cats, husbands who forgot their own anniversaries. Then a forum post caught my eye late one night, an anonymous thread about a missing child, buried under dead links and paranoid warnings. I saved it before I could think twice. By morning, someone already had my number."
	)
	cases[INTRO_ID].unlocked = true   # no interview needed for this one

	_build_case("case1",
		[_t("She's been quiet and distant lately, and strangers have picked her up from school more than once.", true),
		 _t("A stranger in a white van must have taken her from the corner store.", false),
		 _t("I heard she ran off with someone older she met online.", false)],
		"The missing child had grown withdrawn in her final weeks, reportedly seen leaving with unfamiliar adults on more than one occasion."
	)
	_build_case("case2",
		[_t("The family suddenly had money despite being unemployed, and strange visitors came at odd hours.", true),
		 _t("Somebody was owed money and probably took her to settle it.", false),
		 _t("Nobody made her do anything, she chose to leave on her own.", false)],
		"Financial records and witness accounts suggest the household's sudden improvement in finances coincided with unexplained late-night visitors the family refused to discuss."
	)
	_build_case("case3",
		[_t("Her own parents arranged the visits through a local bugaw, calling it a favor for a family friend.", true),
		 _t("I swear I did not know what was really happening.", false),
		 _t("I am a victim in this too, you have to believe me.", false)],
		"Sources allege the child's own parents arranged the visits through a local procurer, exchanging access to their child for money under the guise of a favor for a family friend."
	)

func _t(text: String, is_true: bool) -> Testimony:
	var t := Testimony.new()
	t.text = text
	t.is_true = is_true
	return t

func _build_case(id: String, testimonies: Array[Testimony], manuscript_text: String) -> void:
	testimonies.shuffle()
	var c := CaseData.new()
	c.id = id
	c.testimonies = testimonies
	c.manuscript_text = manuscript_text
	cases[id] = c

## --- DOOR/NPC HOOK ---------------------------------------------------------
## Draw one of the 3 possible testimonies at random (with replacement — a
## "try again" knock can draw the same line or a different one). The
## door/NPC script checks the returned Testimony.is_true itself and calls
## mark_case_unlocked() when it gets the true one.
func draw_testimony(case_id: String) -> Testimony:
	if not cases.has(case_id):
		push_warning("draw_testimony: no case '%s'." % case_id)
		return null
	var pool: Array[Testimony] = cases[case_id].testimonies
	return pool[randi() % pool.size()]

func mark_case_unlocked(case_id: String) -> void:
	if not cases.has(case_id) or cases[case_id].unlocked:
		return
	cases[case_id].unlocked = true
	case_unlocked.emit(case_id)
# ---------------------------------------------------------------------------

## --- BULLETIN BOARD HOOK ---------------------------------------------------
## Call once the puzzle for an unlocked case is solved, right before
## handing off to the Monkeytype game (notepad.start_manuscript(case_id)).
func is_unlocked(case_id: String) -> bool:
	return cases.has(case_id) and cases[case_id].unlocked
# ---------------------------------------------------------------------------

## --- TYPING GAME HOOK -------------------------------------------------------
## Called by noteTypingGame.gd on every keystroke/word so progress survives
## the notepad window being force-closed (e.g. lightmanager.gd cutting
## power and calling computer2.force_shutdown_desktop()).
func save_progress(case_id: String, word_index: int, partial_text: String = "") -> void:
	if not cases.has(case_id):
		return
	cases[case_id].progress_word_index = word_index
	cases[case_id].progress_typed_text = partial_text

## Called by noteTypingGame.gd when (re)opening a manuscript, to resume
## exactly where the player left off.
func get_progress_word_index(case_id: String) -> int:
	if not cases.has(case_id):
		return 0
	return cases[case_id].progress_word_index

func get_progress_typed_text(case_id: String) -> String:
	if not cases.has(case_id):
		return ""
	return cases[case_id].progress_typed_text

## Called by noteTypingGame.gd once the manuscript has been fully typed.
func mark_case_solved(case_id: String) -> void:
	if not cases.has(case_id) or cases[case_id].solved:
		return
	cases[case_id].solved = true
	cases[case_id].progress_word_index = 0
	cases[case_id].progress_typed_text = ""
	case_completed.emit(case_id)

func get_manuscript_text(case_id: String) -> String:
	if not cases.has(case_id):
		return ""
	return cases[case_id].manuscript_text
# ---------------------------------------------------------------------------

## True once all 3 real cases (not counting "intro") are solved.
func is_run_complete() -> bool:
	for id in interview_cases:
		if not cases[id].solved:
			return false
	return true

## The article: every solved entry's manuscript, in order (intro first,
## then case1-3), with the closing headline appended once the 3 real
## cases are all done. Empty until the player types the intro.
func get_article_text() -> String:
	var pieces: Array[String] = []
	for id in order:
		if cases[id].solved:
			pieces.append(cases[id].manuscript_text)
	if pieces.is_empty():
		return "[i]No leads yet.[/i]"
	var text := "\n\n".join(pieces)
	if is_run_complete():
		text += "\n\n" + _final_headline()
	return text

func _final_headline() -> String:
	return "[b]LOCAL COUPLE CHARGED: CHILD TRAFFICKING RING UNCOVERED[/b]\n[i]Investigation reveals parents accepted money in exchange for access to their own child through a local procurer; the case is now tied to a death being investigated as first-degree murder, alongside charges of sex work facilitation and child labor.[/i]"
