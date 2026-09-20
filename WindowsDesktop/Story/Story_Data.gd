extends Node
# Autoload this as "StoryData" (Project Settings > Autoload).
#
# Scope note: this file covers the STORY DATA + TYPING GAME half of the loop
# below. The door-knock/NPC-appearance/bulletin-puzzle SCENES are someone
# else's systems -- this file just exposes what they need to call.
#
#   Run starts -> the 8 witnesses are shuffled into a random knock order
#     -> door/NPC system pulls the next witness id off that order
#     -> draw_testimony_for_witness(witness_id) hands back ONE of that
#        witness's 3 lines (each witness only ever gets ONE draw per run --
#        no re-knocking, no re-drawing)
#     -> [OUT OF SCOPE] NPC scene displays the line
#     -> external script checks the returned Testimony.is_true itself
#     -> if true: call accept_true_testimony() -- this bumps the internal
#        true-count and unlocks the NEXT case in order (case1, then case2,
#        then case3, then case4). Which witness said it does NOT matter --
#        the 4 stages are just "the next 4 true testimonies accepted,"
#        full stop.
#     -> if false: nothing unlocks. Move on to the next witness.
#     -> once 4 TRUE testimonies have been accepted total, the cap is hit --
#        draw_testimony_for_witness() will only ever hand out a FALSE line
#        for every witness knocked after that point, so the remaining
#        witnesses can still be interviewed (flavor/red herrings, no
#        mechanical effect) and all 8 still get exhausted over the run.
#     -> [OUT OF SCOPE] bulletin board hidden-object puzzle for that case
#        (3 evidence items, wrong click = time penalty)
#     -> on puzzle success: Monkeytype game types that case's manuscript
#        (the computer "chapter")
#
# It's all ONE article, assembled in order. "intro" is the first entry --
# unlocked from the start, no testimony needed, so the player has something
# to type before any interviews happen. The 4 real cases (case1-4) unlock
# in strict order as true testimonies come in, and get appended after it.

signal case_unlocked(case_id: String)
signal case_completed(case_id: String)
signal evidence_found(case_id: String, item_id: String)
signal puzzle_solved(case_id: String)
signal testimony_given(witness_id: String, testimony: Testimony)
signal witness_exhausted(witness_id: String)   # emitted the moment a witness has been knocked (their one-shot is used up)

const INTRO_ID := "intro"
const TRUE_TESTIMONY_CAP := 4   # after this many TRUE testimonies are accepted, every later witness is forced to give a false line

class Testimony:
	var text: String = ""
	var is_true: bool = false

class WitnessData:
	var id: String
	var display_name: String = ""
	var testimonies: Array[Testimony] = []   # exactly 3, fixed per witness (2 true/1 false or 1 true/2 false)
	var knocked: bool = false                # true once this witness's one-shot draw has been used
	var given: Testimony = null              # the line they actually ended up giving, once knocked

class CaseData:
	var id: String
	var manuscript_text: String = ""
	var unlocked: bool = false   # true once its turn comes up in the true-testimony order (case1 = 1st true, case2 = 2nd true, etc.)

	# --- hidden object puzzle (bulletin board stage) ---
	var evidence_items: Array[String] = []   # exactly 3 correct item ids ([] for intro)
	var found_items: Array[String] = []      # subset of evidence_items found so far, persists across attempts
	var puzzle_solved: bool = false          # true once all 3 evidence_items have been found

	# --- typing game (Monkeytype) ---
	var solved: bool = false     # true once the manuscript has been typed
	var progress_word_index: int = 0
	var progress_typed_text: String = ""
	var progress_total_typed: int = 0
	var progress_correct_chars: int = 0

var cases: Dictionary = {}          # id -> CaseData
var witnesses: Dictionary = {}      # id -> WitnessData
var witness_order: Array[String] = []   # shuffled once per new_game(); the order the door system should offer knocks in
var order: Array[String] = [INTRO_ID, "case1", "case2", "case3", "case4"]   # article assembly order
var interview_cases: Array[String] = ["case1", "case2", "case3", "case4"]   # gate is_run_complete()
var unlock_sequence: Array[String] = ["case1", "case2", "case3", "case4"]   # which case the 1st/2nd/3rd/4th true testimony unlocks

var true_accepted_count: int = 0

func _ready() -> void:
	randomize()
	new_game()

func new_game() -> void:
	cases.clear()
	witnesses.clear()
	true_accepted_count = 0

	_build_case(INTRO_ID, [],
		"Three weeks in this city and the cases were still routine work; unpaid invoices, wandering house cats, husbands who forgot their own anniversaries. Then a forum post caught my eye late one night -- an anonymous thread about a missing child, buried under dead links and paranoid warnings. I saved it before I could think twice. By morning, someone already had my number."
	)
	cases[INTRO_ID].unlocked = true   # no interview needed for this one

	_build_case("case1",
		["attendance_record", "visitor_log_note", "hallway_graffiti"],
		"The classroom smells like chalk dust; the teacher's hands won't stay still. Unexcused absences, stacked for months. \"I flagged it,\" she says, \"pero walang gumalaw.\" The mother signed the excuse slips herself -- \"family matters,\" vague, rehearsed. Scrawled near the back row, half-erased: \"sugar daddy.\" None of it proves anything. Yet."
	)
	_build_case("case2",
		["hidden_phone", "business_card", "cash_envelope"],
		"Her room is too tidy. Under the bed: a second phone, shoes still boxed, gifts no one explains. A blank business card in a drawer. The father mutters, \"money's been okay lately.\" The mother calls it \"an arrangement,\" voice catching. You write bugaw in the margin; cross it out; write it again."
	)
	_build_case("case3",
		["tire_tracks", "hotel_keycard", "torn_envelope"],
		"Marites remembers a tinted car, past nine -- \"hindi naman akin ang anak.\" An envelope changed hands outside the gate. The basurero found a hotel keycard, half-buried in trash, too embarrassed to say more. None of it proves anything alone. Together, it forms a shape you can't unsee anymore."
	)
	_build_case("case4",
		["worn_footpath", "parked_car_photo", "witness_sketch"],
		"Classmate 3 walks the route by heart -- away from home, toward the old apartments. The same car. The same man, named twice, unprompted. She wasn't running from home; she was being sent out of it. You sit with that before typing your report. Bugaw. Someone who arranges. Someone who profits."
	)

	_build_witness("mother", "Mother", [
		_t("She's been... stressed, that's all. Teenagers get moody, you know? I don't think it's anything serious. She'll turn up.", false),
		_t("Maybe she really did run off with a boy. Kids these days, sila-sila lang, they don't tell us anything anymore.", false),
		_t("She's been going out a lot lately -- with, uh, a friend of mine. Mang Rudy; he helps us with... errands. He checks up on her sometimes. It's fine, it's -- it's a family arrangement, that's all.", true),
	])

	_build_witness("father", "Father", [
		_t("I don't know anything, ha. I'm always at work -- or, wherever. Ask her mother, she's the one who knows the schedule.", false),
		_t("Maybe she just wanted attention. Girls her age, they want drama, that's it.", false),
		_t("Money's been... okay, lately. Since she started going out with her mother's -- her mother's contact. I don't ask questions, why should I? It's not my business what they do.", true),
	])

	_build_witness("marites", "Marites / Neighbor", [
		_t("Naku, I saw her getting picked up -- late, past nine. Not a jeep, not a tricycle -- a private car, tinted pa. I thought, bakit ganoon kagabi? But I didn't say anything, hindi naman akin ang anak.", true),
		_t("I saw her mother outside, talking to a man I didn't recognize; may binigay siyang envelope, parang pera. I thought maybe utang lang. Pero, ewan ko, tumagal sila doon.", true),
		_t("I heard from someone -- I forgot who -- na may boyfriend siya sa ibang school. Baka doon siya tumakas, ano?", false),
	])

	_build_witness("basurero", "Basurero", [
		_t("May nakita ako minsan -- parang sulat, torn na, sabi 'I'm leaving.' Pero baka hindi naman kanya 'yon, ha, marami namang basura dito.", false),
		_t("Nakita ko siyang naglalabas ng maraming damit sa bag, parang malinis pa. Baka... nag-lipat sila ng bahay?", false),
		_t("Sa tapat ng bahay nila, sa basurahan -- may nakita akong... hotel keycard, at saka gamit na, ano, protection. Hindi ko na sinabi kanino, nakakahiya kausapin sila, e.", true),
	])

	_build_witness("classmate1_friend", "Classmate 1 (The Friend)", [
		_t("She seemed happy, actually -- said may boyfriend siya from another school. Sabi niya, 'ipapakilala ko sa'yo balang araw.' Wala akong nakita, pero ganoon sabi niya.", false),
		_t("Baka na-stress lang siya kay Ma'am -- parang mahigpit kasi si teacher tungkol sa grades niya. Baka doon galing lahat 'to.", false),
		_t("She had a new phone, expensive pa; and shoes, gifts -- hindi niya sinasabi galing kanino. Tinanong ko minsan, natawa lang siya, sabi 'wag ka na maingay.' Hindi ko na po tinuloy magtanong.", true),
	])

	_build_witness("classmate2_bully", "Classmate 2 (The Bully)", [
		_t("Ano, bakit ako tinatanong? Fine -- may nadinig lang ako, sa gate, may mga nag-uusap na may 'sugar daddy' daw siya. Hindi ko naman siniraan, totoo lang sinasabi ko.", true),
		_t("Isang beses, nakita ko yung nanay niya, naghihintay sa labas ng gate, may kasamang lalaki sa kotse. Hindi ko sinabi kanino ha, wala lang akong pakialam noon.", true),
		_t("Siya po talaga yung nangbu-bully sa akin, hindi ako. Kaya ayoko na siyang pag-usapan, please.", false),
	])

	_build_witness("classmate3", "Classmate 3", [
		_t("Kadalasan, hindi siya diretso umuuwi -- naglalakad siya papunta sa kabilang barangay, malayo sa bahay nila. May mga apartment doon, luma; hindi ko alam kung bakit doon siya pumupunta.", true),
		_t("Ilang beses ko na siyang nakita, sumasakay sa kotse ng isang matandang lalaki -- hindi ko kilala. Tuwing Huwebes yata 'yon, hindi ako sigurado.", true),
		_t("Baka may tinuturuan lang siya, ganoon -- tutor, malamang. Marami namang nagpapaturo ngayon.", false),
	])

	_build_witness("teacher", "Teacher", [
		_t("Her grades have been slipping, and her attendance too -- absences, unexcused, ilang beses na. I flagged it, pero walang gumalaw.", true),
		_t("Her mother came by once, nag-eexcuse sa absences -- 'family matters' lang, walang detalye. Kinabahan siya nung tinanong ko pa, parang ayaw niyang lumiko sa topic.", true),
		_t("She mentioned once, offhand, na gusto niyang 'mawala na lang.' Baka runaway talaga ang nangyari, hindi ko masyadong pinansin noon, sa totoo lang.", false),
	])

	witness_order.assign(witnesses.keys())
	witness_order.shuffle()

func _t(text: String, is_true: bool) -> Testimony:
	var t := Testimony.new()
	t.text = text
	t.is_true = is_true
	return t

func _build_case(id: String, evidence_items: Array[String], manuscript_text: String) -> void:
	var c := CaseData.new()
	c.id = id
	c.evidence_items = evidence_items
	c.manuscript_text = manuscript_text
	# A case with no evidence items (i.e. "intro") has no bulletin puzzle to
	# solve, so treat it as already solved -- otherwise mark_item_found()
	# never fires for it and the notepad stays permanently locked.
	c.puzzle_solved = evidence_items.is_empty()
	cases[id] = c

func _build_witness(id: String, display_name: String, testimonies: Array[Testimony]) -> void:
	var w := WitnessData.new()
	w.id = id
	w.display_name = display_name
	w.testimonies = testimonies
	witnesses[id] = w

## --- DOOR/NPC HOOK ---------------------------------------------------------
## The order the door system should offer knocks in, for this run. Shuffled
## fresh every new_game() so which witness shows up when is randomized, but
## all 8 ids are always present -- every witness gets exhausted over a run.
func get_witness_order() -> Array[String]:
	return witness_order.duplicate()

func get_witness_display_name(witness_id: String) -> String:
	if not witnesses.has(witness_id):
		return ""
	return witnesses[witness_id].display_name

func has_been_knocked(witness_id: String) -> bool:
	return witnesses.has(witness_id) and witnesses[witness_id].knocked

## Call when this witness's door is knocked on. Each witness is ONE knock
## per run -- calling this again for the same witness just returns the same
## line they already gave (it does not re-roll).
##
## Before the 4-true cap is hit: draws randomly from all 3 of the witness's
## lines (so a 2-true/1-false witness is more likely, but not guaranteed,
## to hand you a true lead).
## After the cap is hit: only the FALSE line(s) in their pool are eligible,
## so every witness knocked after the 4th true testimony gives a false
## statement, no exceptions -- they can still be interviewed for flavor,
## but nothing more will unlock.
func draw_testimony_for_witness(witness_id: String) -> Testimony:
	if not witnesses.has(witness_id):
		push_warning("draw_testimony_for_witness: no witness '%s'." % witness_id)
		return null
	var w: WitnessData = witnesses[witness_id]
	if w.knocked:
		return w.given

	var pool: Array[Testimony] = w.testimonies
	var candidates: Array[Testimony] = pool
	if true_accepted_count >= TRUE_TESTIMONY_CAP:
		var false_only: Array[Testimony] = []
		for t in pool:
			if not t.is_true:
				false_only.append(t)
		candidates = false_only

	var chosen: Testimony = candidates[randi() % candidates.size()]
	w.knocked = true
	w.given = chosen
	testimony_given.emit(witness_id, chosen)
	witness_exhausted.emit(witness_id)
	return chosen

## Call by the door/NPC script once it sees the returned Testimony.is_true
## was true. Bumps the true-count and unlocks whichever case is next in
## unlock_sequence (1st true -> case1, 2nd -> case2, 3rd -> case3,
## 4th -> case4). Which witness said it is irrelevant -- returns the case_id
## that just got unlocked, or "" if the cap was already reached (shouldn't
## normally happen, since draw_testimony_for_witness stops handing out true
## lines once the cap is hit, but the guard is here just in case).
func accept_true_testimony() -> String:
	if true_accepted_count >= TRUE_TESTIMONY_CAP:
		return ""
	var case_id: String = unlock_sequence[true_accepted_count]
	true_accepted_count += 1
	mark_case_unlocked(case_id)
	return case_id

func get_true_accepted_count() -> int:
	return true_accepted_count

func mark_case_unlocked(case_id: String) -> void:
	if not cases.has(case_id) or cases[case_id].unlocked:
		return
	cases[case_id].unlocked = true
	case_unlocked.emit(case_id)
# ---------------------------------------------------------------------------

## --- BULLETIN BOARD HOOK (hidden object puzzle) -----------------------------
## Call once a case has been unlocked (via accept_true_testimony), right
## before letting the player open that case's hidden-object scene.
func is_unlocked(case_id: String) -> bool:
	return cases.has(case_id) and cases[case_id].unlocked

## The 3 correct item ids for this case. The hidden-object scene's clickable
## nodes should be named to match these exactly -- anything else clickable in
## that scene is a decoy (wrong click = time penalty, no story significance).
func get_evidence_items(case_id: String) -> Array[String]:
	if not cases.has(case_id):
		return []
	return cases[case_id].evidence_items.duplicate()

## Items already found for this case, kept across board close/reopen and
## across a failed (timed-out) attempt, so a bad run doesn't wipe items the
## player already legitimately found.
func get_found_items(case_id: String) -> Array[String]:
	if not cases.has(case_id):
		return []
	return cases[case_id].found_items.duplicate()

func is_item_found(case_id: String, item_id: String) -> bool:
	return cases.has(case_id) and item_id in cases[case_id].found_items

## Call when the player clicks a correct evidence item. Returns true if this
## was the 3rd and final item, i.e. the puzzle (60-second search) is now solved.
func mark_item_found(case_id: String, item_id: String) -> bool:
	if not cases.has(case_id):
		return false
	var c: CaseData = cases[case_id]
	if item_id in c.found_items:
		return c.puzzle_solved
	if item_id not in c.evidence_items:
		push_warning("mark_item_found: '%s' is not a listed evidence item for '%s'." % [item_id, case_id])
		return c.puzzle_solved
	c.found_items.append(item_id)
	evidence_found.emit(case_id, item_id)
	if c.found_items.size() >= c.evidence_items.size():
		mark_puzzle_solved(case_id)
	return c.puzzle_solved

func is_puzzle_solved(case_id: String) -> bool:
	return cases.has(case_id) and cases[case_id].puzzle_solved

func mark_puzzle_solved(case_id: String) -> void:
	if not cases.has(case_id) or cases[case_id].puzzle_solved:
		return
	cases[case_id].puzzle_solved = true
	puzzle_solved.emit(case_id)

## Optional: wipes found-item progress for a case. Not called automatically
## on a timed-out attempt -- found items persist by default so a failed run
## isn't a total loss. Wire this in if you'd rather a timeout clear
## everything instead.
func reset_puzzle_progress(case_id: String) -> void:
	if not cases.has(case_id):
		return
	cases[case_id].found_items.clear()
# ---------------------------------------------------------------------------

## --- TYPING GAME HOOK -------------------------------------------------------
## Called by noteTypingGame.gd on every keystroke/word so progress survives
## the notepad window being force-closed (e.g. lightmanager.gd cutting power
## and calling computer2.force_shutdown_desktop()). total_typed and
## correct_chars are saved too, so the accuracy tally can't be reset just by
## closing and reopening the notepad.
func save_progress(case_id: String, word_index: int, partial_text: String, total_typed: int, correct_chars: int) -> void:
	if not cases.has(case_id):
		return
	cases[case_id].progress_word_index = word_index
	cases[case_id].progress_typed_text = partial_text
	cases[case_id].progress_total_typed = total_typed
	cases[case_id].progress_correct_chars = correct_chars

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

func get_progress_total_typed(case_id: String) -> int:
	if not cases.has(case_id):
		return 0
	return cases[case_id].progress_total_typed

func get_progress_correct_chars(case_id: String) -> int:
	if not cases.has(case_id):
		return 0
	return cases[case_id].progress_correct_chars

## Wipes saved progress for a case (used when accuracy drops too low and the
## manuscript has to be restarted from scratch).
func reset_progress(case_id: String) -> void:
	if not cases.has(case_id):
		return
	cases[case_id].progress_word_index = 0
	cases[case_id].progress_typed_text = ""
	cases[case_id].progress_total_typed = 0
	cases[case_id].progress_correct_chars = 0

## Called by noteTypingGame.gd once the manuscript has been fully typed.
func mark_case_solved(case_id: String) -> void:
	if not cases.has(case_id) or cases[case_id].solved:
		return
	cases[case_id].solved = true
	reset_progress(case_id)
	case_completed.emit(case_id)

func get_manuscript_text(case_id: String) -> String:
	if not cases.has(case_id):
		return ""
	return cases[case_id].manuscript_text
# ---------------------------------------------------------------------------

## True once all 4 real cases (not counting "intro") are solved.
func is_run_complete() -> bool:
	for id in interview_cases:
		if not cases[id].solved:
			return false
	return true

## The article: every solved entry's manuscript, in order (intro first, then
## case1-4), with the closing headline appended once all 4 real cases are
## done. Empty until the player types the intro.
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
