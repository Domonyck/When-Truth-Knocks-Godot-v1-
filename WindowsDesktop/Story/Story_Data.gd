extends Node
# Autoload this as "StoryData" (Project Settings > Autoload).

signal case_unlocked(case_id: String)
signal case_completed(case_id: String)
signal evidence_found(case_id: String, item_id: String)
signal puzzle_solved(case_id: String)
signal testimony_given(witness_id: String, testimony: Testimony)
signal witness_exhausted(witness_id: String)
signal conversation_drawn(witness_id: String, lines: Array[DialogueLine])

const INTRO_ID := "intro"
const TRUE_TESTIMONY_CAP := 4

# Maps each witness to the specific case/bulletin stage their testimony unlocks
const WITNESS_CASE_MAP := {
	"teacher": "case1",
	"classmate2_bully": "case1",
	"classmate1_friend": "case2",
	"mother": "case2",
	"marites": "case3",
	"basurero": "case3",
	"classmate3": "case4",
	"father": "case4",
}

# Witness-specific Monkeytype manuscripts loaded when that witness unlocks their case
const WITNESS_MANUSCRIPTS := {
	"teacher": "The classroom smells like chalk dust; the teacher's hands won't stay still. Unexcused absences, stacked for months. \"I flagged it,\" she says, \"pero walang gumalaw.\" Even when she called home, the mother panicked and hung up. None of it proves anything. Yet.",
	"classmate2_bully": "The classroom smells like chalk dust. Behind the bleachers after sixth period, someone saw Maya climb into a black SUV. Scrawled near the back row, half-erased: \"sugar daddy.\" Even the school bully caught her whispering about quotas before crying in the washroom.",
	"classmate1_friend": "Her room is too tidy. Under the bed: a second phone, shoes still boxed, gifts no one explains. Her closest friend noticed the burner phone and designer jackets weeks ago -- and how Maya stared at the floor and told her to shut up. Someone is funding a double life.",
	"mother": "Her room is too tidy. Under the bed: a second phone, shoes still boxed, gifts no one explains. The mother's voice catches when pressed -- admitting Maya has been going out with \"a friend\" named Mang Rudy. She calls it a family arrangement. You write bugaw in the margin.",
	"marites": "Marites remembers a dark tinted sedan idling near the alley past midnight -- \"hindi naman akin ang anak.\" An envelope changed hands outside the gate, followed by expensive cigarette smoke drifting from the shed. Nothing happens on this narrow row without someone watching.",
	"basurero": "Behind the narrow alley row, the green recycling bin tells the story the household won't. The basurero found sealed foil wrappers and adult contraceptives buried beneath ordinary waste -- too embarrassed to confront them. Combined with a hotel keycard in the trash, the pattern is unmistakable.",
	"classmate3": "Classmate 3 walks the route by heart -- away from the north bus stop, toward the old commercial motels downtown. The same red sedan. An older man waiting at the curb, and Maya stepping out clutching a cash-stuffed envelope, completely numb. She wasn't running away; she was being delivered.",
	"father": "The back service exit near the kitchen avoids the neighbor's porch light. Her father finally admits she slipped out through the rear door -- and that money has been \"okay lately\" since she started meeting her mother's contact. You sit with that before typing your report. Bugaw.",
}

class DialogueLine:
	var speaker: String = ""
	var text: String = ""

class Testimony:
	var text: String = ""
	var is_true: bool = false

class WitnessData:
	var id: String
	var display_name: String = ""
	var testimonies: Array[Testimony] = []
	var conversations: Array = []
	var chosen_conversation: Array[DialogueLine] = []
	var knocked: bool = false
	var given: Testimony = null

class CaseData:
	var id: String
	var manuscript_text: String = ""
	var unlocked: bool = false
	var unlocked_by_witness: String = ""

	# --- hidden object puzzle (bulletin board stage) ---
	var evidence_items: Array[String] = []
	var found_items: Array[String] = []
	var puzzle_solved: bool = false

	# --- typing game (Monkeytype) ---
	var solved: bool = false
	var progress_word_index: int = 0
	var progress_typed_text: String = ""
	var progress_total_typed: int = 0
	var progress_correct_chars: int = 0
	var progress_word_states: Array[bool] = []

var cases: Dictionary = {}
var witnesses: Dictionary = {}
var witness_order: Array[String] = []
var order: Array[String] = [INTRO_ID, "case1", "case2", "case3", "case4"]
var interview_cases: Array[String] = ["case1", "case2", "case3", "case4"]
var unlocked_order: Array[String] = []

var true_accepted_count: int = 0
var last_knocked_witness_id: String = ""

func _ready() -> void:
	randomize()
	new_game()

func new_game() -> void:
	cases.clear()
	witnesses.clear()
	unlocked_order.clear()
	true_accepted_count = 0
	last_knocked_witness_id = ""
	order = [INTRO_ID, "case1", "case2", "case3", "case4"]

	_build_case(INTRO_ID, [],
		"Three weeks in this city and the cases were still routine work; unpaid invoices, wandering house cats, husbands who forgot their own anniversaries. Then a forum post caught my eye late one night -- an anonymous thread about a missing child, buried under dead links and paranoid warnings. I saved it before I could think twice. By morning, someone already had my number."
	)
	cases[INTRO_ID].unlocked = true

	_build_case("case1",
		["attendance_record", "visitor_log_note", "hallway_graffiti"],
		WITNESS_MANUSCRIPTS["teacher"]
	)
	_build_case("case2",
		["hidden_phone", "business_card", "cash_envelope"],
		WITNESS_MANUSCRIPTS["mother"]
	)
	_build_case("case3",
		["tire_tracks", "hotel_keycard", "torn_envelope"],
		WITNESS_MANUSCRIPTS["marites"]
	)
	_build_case("case4",
		["worn_footpath", "parked_car_photo", "witness_sketch"],
		WITNESS_MANUSCRIPTS["classmate3"]
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

	_build_all_conversations()

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
	c.puzzle_solved = evidence_items.is_empty()
	cases[id] = c

func _build_witness(id: String, display_name: String, testimonies: Array[Testimony]) -> void:
	var w := WitnessData.new()
	w.id = id
	w.display_name = display_name
	w.testimonies = testimonies
	witnesses[id] = w

## --- CONVERSATION HOOK ------------------------------------------------------
func _line(speaker: String, text: String) -> DialogueLine:
	var d := DialogueLine.new()
	d.speaker = speaker
	d.text = text
	return d

func _add_conversation(witness_id: String, lines: Array[DialogueLine]) -> void:
	if not witnesses.has(witness_id):
		return
	witnesses[witness_id].conversations.append(lines)

func _build_all_conversations() -> void:
	# --- MOTHER ---
	_add_conversation("mother", [
		_line("player", "Come on in out of the rain, Mrs. Reyes. Please, have a seat—no rush at all. I'm investigating Maya's disappearance and just want to help bring her home safely."),
		_line("witness", "Private investigator? Sino nag-hire sa'yo? Hindi naman kami nagbayad ng detective—may blotter na sa presinto."),
		_line("player", "I understand it's overwhelming having someone new ask questions, especially after dealing with the precinct. Whenever you're ready, just tell me how things were at home before she went missing."),
	])
	_add_conversation("mother", [
		_line("player", "Thank you for making the trip up here in this weather, Mrs. Reyes. Take a breath—I know the precinct marked this as a runaway, but I'd rather hear directly from her mother."),
		_line("witness", "Wala naman akong tinatago. Pagod na pagod na ako kakahanap sa District 4, tapos kung anu-ano pang tsismis ang naririnig ko."),
		_line("player", "I hear you, and I'm not here to judge or add to the noise. Take your time and walk me through her last few days at home."),
	])
	_add_conversation("mother", [
		_line("player", "Good evening, Mrs. Reyes. Come sit down and dry off a bit. I've been trying to piece together Maya's timeline around District 4, and I wanted to check in with you directly."),
		_line("witness", "Bakit mga kapitbahay ang pinapakinggan mo? Anak ko si Maya, mas kilala ko siya kaysa kanino man."),
		_line("player", "And that's exactly why you're the person I want to listen to. No pressure—just share your side of what happened."),
	])

	# --- FATHER ---
	_add_conversation("father", [
		_line("player", "Evening, Mr. Reyes. Come in and take a seat—I appreciate you climbing all these stairs after a long shift. I'm following up on Maya's case."),
		_line("witness", "Gabi na ah. Kakauwi ko lang galing trabaho, wala akong gana sa mga imbestiga-imbestiga na 'yan."),
		_line("player", "I completely understand you're exhausted, Sir, so I won't keep you long. Even a small detail from before she went missing could really help."),
	])
	_add_conversation("father", [
		_line("player", "Take a seat and relax for a minute, Mr. Reyes. I've been reviewing the local notes on Maya, and a few neighbors in District 4 mentioned late-night activity near your place."),
		_line("witness", "Sino nagsabi niyan? Mga chismoso sa eskinita namin, walang magawa kundi manilip ng buhay ng may buhay."),
		_line("player", "Neighbors talk, I know how that goes. That's why I'd rather hear the truth straight from you—what was your routine like around the time she left?"),
	])
	_add_conversation("father", [
		_line("player", "Good evening, Sir. Have a seat out of the storm. I'm handling Maya's missing person file, and I just wanted to have a quiet, straightforward chat."),
		_line("witness", "Huwag mo na kaming idamay sa gulo. Dalaga na 'yon, may sariling isip na."),
		_line("player", "I'm not here to cause trouble for your family, Mr. Reyes. She's still sixteen, and anything you noticed could point us in the right direction."),
	])

	# --- MARITES / NEIGHBOR ---
	_add_conversation("marites", [
		_line("player", "Watch your step by the door—the floor's a little wet. Thank you for coming all this way, Ate. You live right beside the Reyes house in District 4, right?"),
		_line("witness", "Oo, magkatabi lang bintana namin! Naku, buti may nag-imbestiga na talaga, kanina pa ako kinakabahan sa mga nangyayari doon."),
		_line("player", "Take your time and catch your breath. You're completely safe here—just tell me calmly whatever you've noticed along the alley."),
	])
	_add_conversation("marites", [
		_line("player", "Good evening, Ate. Please, have a comfortable seat. I'm looking into Maya Reyes's disappearance, and folks on the block mentioned you usually have a good eye on the street."),
		_line("witness", "Hindi naman sa pakialamera ako ha, pero sa kitid ng eskinita namin, kahit kaluskos sa gabi rinig ko."),
		_line("player", "Nobody's calling you nosy—looking out for a missing kid is a good thing. What stood out to you before Maya vanished?"),
	])
	_add_conversation("marites", [
		_line("player", "Pull up a chair and make yourself comfortable. No police uniforms or loud questions here—just a quiet conversation to help find Maya."),
		_line("witness", "Basta huwag mo sasabihin sa mag-asawa na pumunta ako dito ha! Mahirap na, pader lang pagitan namin."),
		_line("player", "You have my word—your name stays completely off the record and between the two of us. Whenever you're ready, tell me what you saw."),
	])

	# --- BASURERO ---
	_add_conversation("basurero", [
		_line("player", "Come on in, Kuya, and don't worry about your boots—the floor's already damp from the rain. You handle the collection route along the District 4 alley, right?"),
		_line("witness", "Opo, Boss. Pero taga-hakot lang po ako ng basura doon, baka wala naman akong alam sa pagkawala nung bata."),
		_line("player", "No pressure at all, Kuya. Sometimes people who work the streets notice the quiet details everyone else misses. Did anything around their place catch your eye?"),
	])
	_add_conversation("basurero", [
		_line("player", "Salamat sa pagpunta, Kuya. Please, take a seat and rest for a bit. I'm investigating Maya Reyes's case, and I'm just checking every part of the neighborhood."),
		_line("witness", "Sa trabaho namin, Boss, marami kang nakikita pero tahimik ka na lang. Ayoko pong madamay sa away-kapitbahay."),
		_line("player", "I respect that, and I won't drag your name into anything. Just share whatever you remember near their curb—it stays strictly between us."),
	])
	_add_conversation("basurero", [
		_line("player", "Good evening, Kuya. Come in out of the weather and have a seat. I'm trying to put together a clear picture of Maya Reyes's routine before she went missing."),
		_line("witness", "Ah, yung dalagita sa dulo ng eskinita? Matagal ko na ring napapansin na kakaiba kilos sa bahay nila."),
		_line("player", "I appreciate you speaking up, Kuya. Take your time—what seemed unusual to you?"),
	])

	# --- CLASSMATE 1 (THE FRIEND) ---
	_add_conversation("classmate1_friend", [
		_line("player", "Hey, come on in and take a seat. Don't be nervous—you're not in any trouble at all. I'm just investigating Maya's disappearance so we can find her."),
		_line("witness", "Opo... magkaibigan po kami sa school, pero hindi ko po talaga alam kung nasaan siya ngayon."),
		_line("player", "I believe you, and I'm glad she had a good friend like you. Just take it easy and tell me how she was acting in the weeks before she stopped coming to class."),
	])
	_add_conversation("classmate1_friend", [
		_line("player", "Rough night to travel across town—thanks for coming up here. You and Maya were pretty close at school, weren't you?"),
		_line("witness", "Natatakot po kasi ako baka magalit si Tita—yung mama niya—pag nalaman niyang nakikipag-usap ako sa detective."),
		_line("player", "You don't have to worry about that. Her parents won't hear a single word from me—just share whatever you feel comfortable telling me."),
	])
	_add_conversation("classmate1_friend", [
		_line("player", "Have a seat and relax for a moment. I've been reading through Maya's file, and honestly, the rumors going around don't quite match the girl you knew."),
		_line("witness", "Sabi ng iba naglayas daw siya, pero... hindi naman siya ganoon dati eh."),
		_line("player", "That's really helpful to hear. Whenever you're ready, tell me what you noticed changing with her."),
	])

	# --- CLASSMATE 2 (THE BULLY) ---
	_add_conversation("classmate2_bully", [
		_line("player", "Hey, come in and take a seat. I know an investigator's office isn't where you want to spend your evening, so I'll keep this brief and straightforward."),
		_line("witness", "Tss. Bakit ako pinatawag mo? Hindi naman kami close ni Maya, wala akong pake kung saan siya nagpunta."),
		_line("player", "Fair enough—you don't have to be friends with someone to notice what happens around school. Just tell me calmly whatever you happened to see."),
	])
	_add_conversation("classmate2_bully", [
		_line("player", "Come on in out of the rain. I'm looking into Maya Reyes's disappearance, and a few people mentioned you might have noticed who she hung around with."),
		_line("witness", "Kung iniisip mong may kinalaman ako sa pagkawala niya, nagkakamali ka."),
		_line("player", "Relax, nobody's pointing fingers at you here. I'm just trying to get the full picture—what did you observe around campus?"),
	])
	_add_conversation("classmate2_bully", [
		_line("player", "Have a seat—no need to stay on guard. Most of your class seems hesitant to talk about Maya, so I appreciate you showing up."),
		_line("witness", "Eh totoo namang maraming kalokohan 'yon pagkatapos ng klase, nagbabait-baitan lang."),
		_line("player", "All right, I'm listening. Tell me plainly what you saw after classes let out."),
	])

	# --- CLASSMATE 3 ---
	_add_conversation("classmate3", [
		_line("player", "Good evening. Thanks for coming up to the office in this weather—have a seat. I'm just trying to trace Maya's usual route after dismissal."),
		_line("witness", "Ah, sabay po kami minsan lumalabas ng gate, pero naghihiwalay din kami pagdating sa sakayan."),
		_line("player", "That's already a big help. Do you remember which direction she usually headed from there?"),
	])
	_add_conversation("classmate3", [
		_line("player", "Come in and make yourself comfortable. I'm investigating Maya Reyes's case, and I'm grateful you took the time to stop by."),
		_line("witness", "Hindi ko po alam kung makakatulong 'to, pero ilang beses ko siyang nakita pagkatapos ng klase."),
		_line("player", "Even small details end up being the most important ones. Take your time and tell me what you saw."),
	])
	_add_conversation("classmate3", [
		_line("player", "Have a seat out of the rain. I'm putting together a timeline of Maya's last few weeks—you sat near her in class, right?"),
		_line("witness", "Opo. Tahimik lang siya nitong mga nakaraang buwan, parang laging nagmamadali umalis pag-bell."),
		_line("player", "I appreciate you paying attention. Did you ever notice where she was heading in such a hurry?"),
	])

	# --- TEACHER ---
	_add_conversation("teacher", [
		_line("player", "Good evening, Ma'am. Please, have a seat—thank you so much for making time after school hours to help with Maya's case."),
		_line("witness", "Matagal na akong nag-aalala kay Maya. Sa wakas may nag-iimbestiga nang seryoso sa kaso niya."),
		_line("player", "I'm glad we could speak. You know her classroom routine best, so whenever you're ready, walk me through what you noticed."),
	])
	_add_conversation("teacher", [
		_line("player", "Come on in out of the rain, Ma'am, and make yourself comfortable. I'm investigating Maya Reyes's disappearance and wanted to check in with you."),
		_line("witness", "Sa totoo lang, matino siyang estudyante dati. Bigla na lang nagbago nitong huling dalawang buwan."),
		_line("player", "That's a really important detail. Could you tell me a bit more about those changes—and how her family responded when you reached out?"),
	])
	_add_conversation("teacher", [
		_line("player", "Thank you for coming up to this quiet loft, Ma'am. Take a breath—I just want to have a calm, thorough look at Maya's behavior at school."),
		_line("witness", "Basta makatulong mahanap si Maya, sasabihin ko lahat ng nasa record ko at lahat ng napansin ko."),
		_line("player", "I truly appreciate your openness, Ma'am. Take your time and start wherever feels right."),
	])

func draw_conversation_for_witness(witness_id: String) -> Array[DialogueLine]:
	if not witnesses.has(witness_id):
		push_warning("draw_conversation_for_witness: no witness '%s'." % witness_id)
		return []
	var w: WitnessData = witnesses[witness_id]
	if not w.chosen_conversation.is_empty():
		return w.chosen_conversation
	if w.conversations.is_empty():
		return []
	var picked: Array = w.conversations[randi() % w.conversations.size()]
	var chosen: Array[DialogueLine] = []
	chosen.assign(picked)
	w.chosen_conversation = chosen
	conversation_drawn.emit(witness_id, chosen)
	return chosen
# ---------------------------------------------------------------------------

## --- DOOR/NPC HOOK ---------------------------------------------------------
func get_witness_order() -> Array[String]:
	return witness_order.duplicate()

func get_witness_display_name(witness_id: String) -> String:
	if not witnesses.has(witness_id):
		return ""
	return witnesses[witness_id].display_name

func has_been_knocked(witness_id: String) -> bool:
	return witnesses.has(witness_id) and witnesses[witness_id].knocked

func draw_testimony_for_witness(witness_id: String) -> Testimony:
	if not witnesses.has(witness_id):
		push_warning("draw_testimony_for_witness: no witness '%s'." % witness_id)
		return null
	var w: WitnessData = witnesses[witness_id]
	last_knocked_witness_id = witness_id
	if w.knocked:
		return w.given

	var target_case: String = WITNESS_CASE_MAP.get(witness_id, "")
	var case_already_unlocked: bool = not target_case.is_empty() and is_unlocked(target_case)

	var pool: Array[Testimony] = w.testimonies
	var candidates: Array[Testimony] = pool
	if true_accepted_count >= TRUE_TESTIMONY_CAP or case_already_unlocked:
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

func accept_true_testimony(witness_id: String = "") -> String:
	if true_accepted_count >= TRUE_TESTIMONY_CAP:
		return ""

	var w_id := witness_id if not witness_id.is_empty() else last_knocked_witness_id
	var case_id: String = WITNESS_CASE_MAP.get(w_id, "")

	if case_id.is_empty() or not cases.has(case_id) or cases[case_id].unlocked:
		for id in interview_cases:
			if not cases[id].unlocked:
				case_id = id
				break

	if case_id.is_empty():
		return ""

	if WITNESS_MANUSCRIPTS.has(w_id):
		cases[case_id].manuscript_text = WITNESS_MANUSCRIPTS[w_id]
	cases[case_id].unlocked_by_witness = w_id

	true_accepted_count += 1
	unlocked_order.append(case_id)
	_rebuild_article_order()
	mark_case_unlocked(case_id)
	return case_id

func _rebuild_article_order() -> void:
	var new_order: Array[String] = [INTRO_ID]
	for id in unlocked_order:
		if id not in new_order:
			new_order.append(id)
	for id in interview_cases:
		if id not in new_order:
			new_order.append(id)
	order = new_order

func get_true_accepted_count() -> int:
	return true_accepted_count

func mark_case_unlocked(case_id: String) -> void:
	if not cases.has(case_id) or cases[case_id].unlocked:
		return
	cases[case_id].unlocked = true
	case_unlocked.emit(case_id)
# ---------------------------------------------------------------------------

## --- BULLETIN BOARD HOOK (hidden object puzzle) -----------------------------
func is_unlocked(case_id: String) -> bool:
	return cases.has(case_id) and cases[case_id].unlocked

func get_evidence_items(case_id: String) -> Array[String]:
	if not cases.has(case_id):
		return []
	return cases[case_id].evidence_items.duplicate()

func get_found_items(case_id: String) -> Array[String]:
	if not cases.has(case_id):
		return []
	return cases[case_id].found_items.duplicate()

func is_item_found(case_id: String, item_id: String) -> bool:
	return cases.has(case_id) and item_id in cases[case_id].found_items

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

func reset_puzzle_progress(case_id: String) -> void:
	if not cases.has(case_id):
		return
	cases[case_id].found_items.clear()
# ---------------------------------------------------------------------------

## --- TYPING GAME HOOK -------------------------------------------------------
func save_progress(case_id: String, word_index: int, partial_text: String, total_typed: int, correct_chars: int, word_states: Array[bool] = []) -> void:
	if not cases.has(case_id):
		return
	cases[case_id].progress_word_index = word_index
	cases[case_id].progress_typed_text = partial_text
	cases[case_id].progress_total_typed = total_typed
	cases[case_id].progress_correct_chars = correct_chars
	cases[case_id].progress_word_states = word_states.duplicate()

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

func save_word_states(case_id: String, states: Array[bool]) -> void:
	if not cases.has(case_id):
		return
	cases[case_id].progress_word_states = states.duplicate()

func get_progress_word_states(case_id: String) -> Array[bool]:
	if not cases.has(case_id):
		return []
	return cases[case_id].progress_word_states.duplicate()

func reset_progress(case_id: String) -> void:
	if not cases.has(case_id):
		return
	cases[case_id].progress_word_index = 0
	cases[case_id].progress_typed_text = ""
	cases[case_id].progress_total_typed = 0
	cases[case_id].progress_correct_chars = 0
	cases[case_id].progress_word_states.clear()

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

func get_next_puzzle_case() -> String:
	for id in unlocked_order:
		if cases[id].unlocked and not cases[id].puzzle_solved:
			return id
	for id in interview_cases:
		if cases[id].unlocked and not cases[id].puzzle_solved:
			return id
	return ""

func is_run_complete() -> bool:
	for id in interview_cases:
		if not cases[id].solved:
			return false
	return true

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
