-- Trainer Beacon rematch dialogue.
--
-- Every supported ordinary Gen 1 trainer type gets exactly ten fully authored
-- first-rematch and ten later-rematch variants. The pools intentionally mix
-- neutral competition, class-flavoured humour, and occasional darker/spookier
-- lines without making every trainer sound like the same character.
-- Unknown/modded classes use a separate 10+10 generic fallback.

local Dialogue = {}

local P = {
  OPP_YOUNGSTER = {
    first = {
      "I trained all week. Well, most of Tuesday.",
      "My {STRONGEST} says we're ready. I chose to believe it.",
      "I told everyone I'd win the rematch. Please don't make this weird.",
      "Last time hurt my pride more than my Pokemon. Somehow that's worse.",
      "I bought a notebook for strategies. Page one just says DON'T LOSE.",
      "My friends said to let it go. They are not invited to this battle.",
      "I practiced my victory pose. That's basically training, right?",
      "{STRONGEST} got stronger. I got louder. It should balance out.",
      "You won the first one. I have been replaying that before bed ever since.",
      "If I lose twice, this becomes a story people tell about me. No pressure.",
    },
    later = {
      "You're back? Good. I finally stopped explaining the last one.",
      "My {STRONGEST} has a strategy. I have snacks. We're prepared.",
      "If I lose again, I'm calling this advanced training.",
      "One day I'll be the trainer people warn kids about. Not today, apparently.",
      "I changed my whole plan. It still starts with GO, {STRONGEST}.",
      "At this point my mom thinks you're one of my friends.",
      "I have more rematches with you than homework finished this month.",
      "{STRONGEST} recognizes that look. So do I, unfortunately.",
      "I stopped counting losses. That was a very healthy decision.",
      "Keep coming back. Eventually one of us grows out of this.",
    },
  },
  OPP_BUG_CATCHER = {
    first = {
      "I brought extra ANTIDOTES. Mostly for my pride.",
      "My {STRONGEST} came out stronger. I came out itchier.",
      "The forest eats weak things. Today it gets to watch.",
      "Every cocoon opens eventually. So does every grudge.",
      "I spent three days in tall grass for this. My socks may never recover.",
      "{STRONGEST} has been training. I have been getting bitten.",
      "You beat my bugs once. They took that surprisingly personally.",
      "My net catches everything except a decent excuse for losing.",
      "The small ones are always underestimated. That's why they survive.",
      "I found a new strategy under a log. Don't ask what else was under there.",
    },
    later = {
      "I upgraded my net. It still doesn't catch excuses.",
      "{STRONGEST} molted. I just got more stubborn.",
      "The bugs don't remember losing. Lucky them.",
      "Keep coming back. The forest has room for another bad memory.",
      "I know your battle style now. I also know six kinds of beetle you don't.",
      "{STRONGEST} sees you and starts buzzing. I choose to call that confidence.",
      "I have stopped promising this will be the last rematch.",
      "The forest is quiet today. It usually gets quiet before something gets eaten.",
      "My team keeps evolving. My social life is going the other direction.",
      "One of these days the cocoon opens and you won't like what comes out.",
    },
  },
  OPP_LASS = {
    first = {
      "I practiced a whole speech for this. The BEACON ruined the timing.",
      "{STRONGEST} is ready. I am choosing to look equally ready.",
      "I fixed my team and my attitude. One of those was harder.",
      "I remember exactly how you won. That's the annoying part.",
      "I told everyone the first battle was close. Please cooperate with that version.",
      "{STRONGEST} has been training. I have been holding a grudge very elegantly.",
      "I changed my lineup and bought better shoes. Both seemed important.",
      "This time I brought a plan instead of confidence. Much lighter to carry.",
      "You made losing look easy. I would like to return the favor.",
      "Some memories fade. The embarrassing ones apparently have excellent endurance.",
    },
    later = {
      "Again? At least give me time to invent a better excuse.",
      "{STRONGEST} recognizes you. That little glare is new.",
      "I'm running out of things to blame besides you.",
      "Some losses fade. Yours keep getting appointments.",
      "I had plans today. Apparently losing track of you wasn't one of them.",
      "{STRONGEST} is ready. I also brought the good hair tie. Serious business.",
      "You are becoming a recurring problem with very good timing.",
      "If this keeps happening, I'm charging you for emotional damages.",
      "I don't hold grudges forever. I schedule them.",
      "One day this rematch habit ends. I would prefer that day involve me winning.",
    },
  },
  OPP_SAILOR = {
    first = {
      "I've fought storms meaner than you. Storms don't use POTIONS, though.",
      "{STRONGEST} found its sea legs. I never lost mine.",
      "A rematch beats scrubbing the deck. Barely.",
      "The sea teaches one lesson: anything can disappear over the horizon.",
      "I trained through rough water for this. You had better be worth the seasickness.",
      "{STRONGEST} is ready. The deck is tied down. Let's see what moves first.",
      "Last time you sank my plan before it left port.",
      "A good sailor learns from every wreck. Even the embarrassing little ones.",
      "The ocean gives second chances. It just doesn't always give people back with them.",
      "I promised the crew I'd settle this. They mostly laughed.",
    },
    later = {
      "Back aboard? You must really hate dry land.",
      "{STRONGEST} is ready to make waves. Yes, I know how that sounded.",
      "I've tied knots less complicated than our battle record.",
      "The ocean doesn't keep score. I do.",
      "Another rematch? Fine. The tide came back too.",
      "{STRONGEST} has seen worse weather and, somehow, more of you.",
      "At this point you're practically cargo. Annoying, recurring cargo.",
      "I stopped telling the crew how many times we've done this.",
      "Every sailor knows when a storm is coming. Your BEACON has the same feeling.",
      "One bad wave can take a whole deck quiet. Let's keep this one friendly.",
    },
  },
  OPP_JR_TRAINER_M = {
    first = {
      "I reviewed every mistake. There were enough for a full lesson.",
      "{STRONGEST} and I drilled this rematch until it stopped being fun.",
      "Coach said stay focused. The BEACON apparently counts as focus.",
      "Losing once is instruction. Losing twice would be a habit.",
      "I timed every practice session. I did not time the sulking afterward.",
      "{STRONGEST} improved exactly as planned. Now you just need to cooperate.",
      "I rewrote the strategy after the first loss. Twice.",
      "No improvising this time. Improvising is how the last disaster happened.",
      "A trainer should learn from defeat. I learned that I hate defeat.",
      "This is the rematch portion of my training plan. It is underlined three times.",
    },
    later = {
      "Another rematch. Good. Repetition builds discipline.",
      "{STRONGEST} knows your tricks now. I wrote them down.",
      "I have a new plan and fewer excuses.",
      "Eventually practice stops feeling like practice and starts feeling personal.",
      "I logged every battle. The graph is becoming rude.",
      "{STRONGEST} is hitting target times. You're the remaining variable.",
      "Coach called this excessive. I called it commitment.",
      "We know each other's openings now. That makes mistakes harder to hide.",
      "Training removes weakness slowly. Pride goes faster.",
      "Again. No speeches. The schedule says battle.",
    },
  },
  OPP_JR_TRAINER_F = {
    first = {
      "I studied the battle afterward. You were irritatingly educational.",
      "{STRONGEST} is sharper now. So is the rest of the team.",
      "I made a training schedule. It has your name under TEST DAY.",
      "A clean loss still leaves a mark. Let's see what a clean win does.",
      "I corrected every mistake I could find. You may have invented new ones for me.",
      "{STRONGEST} passed every drill. You are the final exam.",
      "I don't need revenge. I do need better results.",
      "The first battle exposed the weak points. That was useful, annoyingly.",
      "I told myself not to take this personally. Then I made a whole schedule around you.",
      "Good training is controlled pressure. Let's see which of us cracks first.",
    },
    later = {
      "Good timing. We just finished practicing how not to lose to you.",
      "{STRONGEST} learned the routine. I changed it anyway.",
      "My notes on you need another page.",
      "Some lessons only stick when they hurt your pride.",
      "The schedule says REST DAY. I'm making an exception.",
      "{STRONGEST} improved again. You keep making the benchmarks inconvenient.",
      "I've stopped calling these surprise rematches.",
      "Every repeated mistake becomes a choice eventually.",
      "You are very good at turning training data into grudges.",
      "Let's keep this efficient. I have corrections to make afterward.",
    },
  },
  OPP_POKEMANIAC = {
    first = {
      "I've been researching your team. Normal amount. Completely normal.",
      "{STRONGEST} and I have theories about you. Mostly unflattering ones.",
      "The BEACON found me? Excellent. Saves me looking for you.",
      "People call obsession unhealthy right up until it starts winning battles.",
      "I catalogued the first fight frame by frame. There were a lot of frames.",
      "{STRONGEST} has a new training regimen. I designed six versions.",
      "I knew you'd want a rematch. I did not know when. I have been carrying supplies.",
      "Your team composition is fascinating. Your victory was less charming.",
      "Some collectors keep trophies. I keep detailed reasons to try again.",
      "If this goes badly, at least the notes will be excellent.",
    },
    later = {
      "You're back! Great. My notes were becoming dangerously hypothetical.",
      "{STRONGEST} remembers you. I have charts proving it.",
      "I revised the matchup table. And the backup matchup table.",
      "There is a point where research becomes fixation. We passed it two rematches ago.",
      "I numbered our battles. That was a mistake once the number got embarrassing.",
      "{STRONGEST} has its own section in the notebook now. You have three.",
      "I've learned so much from losing to you. I would like to stop learning.",
      "My family says I talk about this rivalry too much. They are not qualified reviewers.",
      "The data is clear: one of us is becoming a problem.",
      "Another trial. Excellent. Healthy? Debatable. Excellent? Absolutely.",
    },
  },
  OPP_SUPER_NERD = {
    first = {
      "I recalculated everything. The calculator asked for a break.",
      "According to my model, {STRONGEST} wins this. Please don't introduce new data.",
      "I corrected the obvious error: assuming you'd be easy.",
      "Failure is data. Enough data starts to look like a warning.",
      "I ran ten simulations. You somehow annoyed me in all of them.",
      "{STRONGEST} has optimal parameters. I have acceptable parameters.",
      "The first loss was statistically significant and emotionally unnecessary.",
      "I added a column called THINGS YOU DID WRONG. It became inconveniently short.",
      "Probability is comforting until the improbable thing is standing in front of you.",
      "If the model fails again, I am blaming the model in writing.",
    },
    later = {
      "New model. Same opponent. Statistically this has to work eventually.",
      "{STRONGEST} is operating within improved parameters. I am not.",
      "I added a margin of error. It has your name on it.",
      "The numbers stopped being comforting a while ago.",
      "Another data point. Wonderful. My confidence interval is crying.",
      "{STRONGEST} is above projection. You remain offensively hard to project.",
      "I simplified the equation: you plus me equals another rematch.",
      "My spreadsheet has started auto-filling your name.",
      "Eventually the anomaly becomes the pattern. I dislike where this is heading.",
      "Let's test the revised hypothesis before I revise my career.",
    },
  },
  OPP_HIKER = {
    first = {
      "I climbed a mountain to train. Then I remembered the Pokemon did most of the work.",
      "{STRONGEST} is tougher now. My knees are not.",
      "You beat me once. Uphill both ways, somehow.",
      "The mountain keeps every footprint until the weather decides otherwise.",
      "I trained at altitude. Mostly because that's where I already was.",
      "{STRONGEST} can take a hit now. I can take a sandwich.",
      "The first loss rolled downhill faster than I did.",
      "A long trail gives you time to rethink mistakes. Too much time, honestly.",
      "Rocks remember pressure by changing shape. People aren't so different.",
      "I came back stronger. Also dustier.",
    },
    later = {
      "You again? Fine. I needed an excuse to stop walking.",
      "{STRONGEST} trained on rock. I trained on sandwiches.",
      "At this point you're part of the route.",
      "Rock wears down slowly. So do people.",
      "Another rematch? I should start charging trail fees.",
      "{STRONGEST} knows your scent. That's probably the hiking clothes.",
      "I've climbed less stubborn mountains than this rivalry.",
      "My boots have more wins than I do. They beat a puddle this morning.",
      "The path back is always shorter until it isn't.",
      "Come on, then. The mountain isn't going anywhere, and apparently neither are you.",
    },
  },
  OPP_BIKER = {
    first = {
      "The BEACON beeped at me. I almost threw it in a ditch.",
      "{STRONGEST} is tuned up. I'm still making that everyone else's problem.",
      "Last time was a bad turn. This time I know the road.",
      "Roads don't care who gets back up. I do. Unfortunately.",
      "I trained until the engine cooled down. Then I remembered Pokemon aren't engines.",
      "{STRONGEST} is ready. The neighbors have already complained.",
      "You embarrassed me in public. Conveniently, I enjoy public rematches.",
      "I changed routes, tactics, and one questionable tire.",
      "Every road looks safe right before somebody misjudges the corner.",
      "Let's settle this before I decide the BEACON would look better under a wheel.",
    },
    later = {
      "Again? You collect rematches like road rash.",
      "{STRONGEST} is louder now. Somehow.",
      "I know this road and I know your tricks.",
      "Keep pushing your luck. Every road ends somewhere.",
      "The BEACON found me again. Technology was a mistake.",
      "{STRONGEST} sees you and starts pacing. Same, honestly.",
      "I've taken worse turns. Not many, but worse.",
      "At this point the gang thinks you're my training partner. Don't get comfortable.",
      "Speed makes mistakes shorter, not safer.",
      "One more lap. Try not to become scenery.",
    },
  },
  OPP_BURGLAR = {
    first = {
      "A gadget that calls people back? That's worth stealing after the battle.",
      "{STRONGEST} is ready. And no, you didn't see where I got the training gear.",
      "I learned from last time. Mostly which exits not to use.",
      "Dark rooms teach you things daylight politely avoids.",
      "You won once. I consider that unauthorized possession of my dignity.",
      "{STRONGEST} trained somewhere private. Very private. Ask fewer questions.",
      "I brought a better plan and absolutely no stolen supplies.",
      "The first fight went bad fast. I respect fast things, usually.",
      "Locks aren't the only things people remember breaking.",
      "If anyone asks, this rematch never happened.",
    },
    later = {
      "You again? This is becoming terrible for my professional image.",
      "{STRONGEST} is legit. The rest of my story is none of your business.",
      "I changed the plan. Fewer alarms this time.",
      "Locks aren't the only things that break if you keep testing them.",
      "The BEACON keeps finding me. I need to steal a quieter life.",
      "{STRONGEST} remembers you. I remember where the exits are.",
      "Another rematch? Fine. Keep your hands where I can see them. Irony noted.",
      "I used to avoid repeat jobs. Then you became one.",
      "Every clean getaway starts with knowing when not to stay.",
      "Let's finish before somebody with a badge notices us.",
    },
  },
  OPP_ENGINEER = {
    first = {
      "I fixed the plan. The plan now has fewer exposed wires.",
      "{STRONGEST} passed inspection. I waived several standards.",
      "The BEACON's signal is sloppy. Effective, though.",
      "Machines fail cleanly. People usually make more noise.",
      "I recalibrated the team. The wrench was mostly symbolic.",
      "{STRONGEST} is running within tolerance. My patience isn't.",
      "The first battle exposed a design flaw. The design flaw was confidence.",
      "I made a checklist. You're item seven: REMOVE RECURRING PROBLEM.",
      "A loose connection looks harmless until something starts smoking.",
      "Try not to touch anything while we battle. Especially my last nerve.",
    },
    later = {
      "I rebuilt the strategy. Again. Please stop creating maintenance work.",
      "{STRONGEST} is calibrated for this exact problem: you.",
      "If this fails, I'm blaming signal interference.",
      "Every system has a breaking point. Testing is how you find it.",
      "The BEACON passed diagnostics. I was hoping it hadn't.",
      "{STRONGEST} is stable. The rematch schedule is not.",
      "I replaced three parts and one assumption.",
      "This rivalry now has more revisions than the machine manual.",
      "Metal gives warnings before it fails. People call those warnings stress.",
      "Let's run the test again. I hate that sentence now.",
    },
  },
  OPP_JUGGLER = {
    first = {
      "Good news: I dropped fewer balls in practice. Bad news: Pokemon aren't balls.",
      "{STRONGEST} is the one thing I refuse to juggle.",
      "I can keep four things in the air. Winning should be one of them.",
      "The trick is smiling while everything is one mistake from the floor.",
      "I rehearsed the rematch. You missed your cue last time by winning.",
      "{STRONGEST} gets top billing tonight.",
      "I added a new trick called NOT LOSING. Still experimental.",
      "The audience loved the first battle. Traitors.",
      "Every good act has danger. Mostly for the performer.",
      "No refunds if this ends badly.",
    },
    later = {
      "Back again? Fine. Add one more thing to the routine.",
      "{STRONGEST} knows the cue. I hope I do.",
      "If I lose, I'm calling it performance art.",
      "Eventually every act ends. The audience just doesn't know when.",
      "The BEACON is becoming part of the show. I hate its timing.",
      "{STRONGEST} gets an encore. You get no applause yet.",
      "I can juggle pressure, pride, and bad odds. Apparently not you.",
      "We've done this so often I should charge admission.",
      "A dropped ball bounces. Some mistakes don't.",
      "Places, everyone. The recurring disaster has arrived.",
    },
  },
  OPP_FISHER = {
    first = {
      "I caught nothing all morning, so apparently you're the day's big one.",
      "{STRONGEST} took the bait. Now let's see if you do.",
      "I had hours to think about that loss. Fishing gives you too much time.",
      "Deep water keeps what it gets. Let's stay on shore.",
      "The fish weren't biting, so I trained instead. Terrible day for everyone.",
      "{STRONGEST} is ready. My line is tangled, but that seems unrelated.",
      "I replayed our battle while staring at a float for six hours.",
      "You got away once. I dislike the metaphor already.",
      "Still water can hide a lot. Mostly disappointment today.",
      "Let's see whether patience finally pays out.",
    },
    later = {
      "You again? Better bite than anything in this water.",
      "{STRONGEST} is ready. The fish still aren't.",
      "I changed bait, line, and battle plan. Something has to work.",
      "Still water looks harmless. That's usually when it's deepest.",
      "Another rematch? At least you respond faster than MAGIKARP.",
      "{STRONGEST} knows the hook now. So do you.",
      "I've landed fewer fish than rematches this week.",
      "The lake is peaceful. You're ruining that very efficiently.",
      "Some things pull harder the closer they get to the surface.",
      "All right. One more cast.",
    },
  },
  OPP_SWIMMER = {
    first = {
      "I trained while you stayed dry. Unfair advantage, really.",
      "{STRONGEST} is warmed up. I am literally already wet.",
      "Last battle sank fast. This one gets a better start.",
      "Water closes over mistakes quickly. People don't.",
      "I did fifty laps after losing. Anger is excellent cardio.",
      "{STRONGEST} is ready. Try not to splash the spectators.",
      "You caught me off balance last time. Hard to do while floating.",
      "I practiced turns, breathing, and not underestimating strangers.",
      "The deep end is only scary until you know what's under you.",
      "Let's make this quick. I'm getting cold.",
    },
    later = {
      "Back for another lap? Try to keep up.",
      "{STRONGEST} is ready. I didn't even need a towel this time.",
      "I know your rhythm now. Every swimmer has one.",
      "You can fight a current for a long time before noticing how far it carried you.",
      "The BEACON beeped underwater. I am impressed and annoyed.",
      "{STRONGEST} is warmed up. You're the interval training.",
      "Another rematch? Fine. First one to drown in excuses loses.",
      "I stopped counting laps and started counting you showing up.",
      "Calm water can turn fast. So can a battle.",
      "One more length. No grabbing the lane rope.",
    },
  },
  OPP_CUE_BALL = {
    first = {
      "Last time was a scratch. This time I call the shot.",
      "{STRONGEST} is lined up. Don't move.",
      "The BEACON wants a rematch? Rack 'em up.",
      "Everybody acts tough until the table goes quiet.",
      "I practiced angles after losing. Turns out anger has terrible geometry.",
      "{STRONGEST} is my clean shot. You're the clutter.",
      "You ran the table last time. I remember every ball.",
      "I don't miss twice. Usually.",
      "One bad bounce is funny. A whole night of them isn't.",
      "Let's settle this before someone asks whose turn it is.",
    },
    later = {
      "Again? You're really leaning on this table.",
      "{STRONGEST} has the angle now.",
      "Same game. Better break.",
      "Keep taking shots. Eventually something important drops.",
      "The BEACON called. I chalked the cue.",
      "{STRONGEST} is set. No trick shot needed.",
      "I've seen hustlers with less commitment than you.",
      "Every rematch adds another dent to the same old table.",
      "A quiet room makes every miss sound worse.",
      "Break time's over. Your move.",
    },
  },
  OPP_GAMBLER = {
    first = {
      "I don't chase losses. Usually. Today is apparently special.",
      "I'm putting everything on {STRONGEST}. Figuratively. Mostly.",
      "The odds were bad last time. I blame the odds.",
      "Luck is comforting right up until it starts remembering your name.",
      "I flipped a coin on whether to accept. It landed on the BEACON.",
      "{STRONGEST} is my safest bet. That should concern both of us.",
      "The first battle was variance. Please let me keep saying that.",
      "I doubled down on training because apparently dignity has no limit.",
      "Everybody loves chance until chance starts collecting.",
      "One more wager. Winner gets to be unbearable about it.",
    },
    later = {
      "Double or nothing stopped making sense three battles ago.",
      "{STRONGEST} is my safest bet. That says more about me than it should.",
      "The house always wins. I need to find a house.",
      "Every losing streak ends. So does every lucky one.",
      "The BEACON again? Fine. Put it all on stubbornness.",
      "{STRONGEST} has better odds now. I checked twice.",
      "I stopped tracking the money and started tracking the insult.",
      "Our battle history looks like a bad betting system.",
      "Luck doesn't owe anyone a refund.",
      "Place your bets. Apparently we're doing this forever.",
    },
  },
  OPP_BEAUTY = {
    first = {
      "I changed my strategy. The hair was already perfect.",
      "{STRONGEST} is ready, and yes, we coordinated.",
      "Losing was ugly. I fixed what I could.",
      "A smile is useful. People stop watching your hands.",
      "I trained hard enough to ruin a manicure. Appreciate the sacrifice.",
      "{STRONGEST} looks fantastic. Winning would complete the outfit.",
      "You made the first battle look effortless. Rude.",
      "I replaced embarrassment with preparation. Much more flattering.",
      "Pretty things can still leave scars. Usually metaphorical ones.",
      "Let's get this over with before the weather changes.",
    },
    later = {
      "Again? Fine. At least this lighting is decent.",
      "{STRONGEST} looks confident. I taught that part personally.",
      "I refuse to make losing to you part of my look.",
      "Pretty things can still have sharp edges.",
      "The BEACON caught me between appointments. You're now the worse one.",
      "{STRONGEST} remembers you. Not fondly.",
      "I've changed outfits fewer times than I've changed plans for you.",
      "At least recurring problems are predictable.",
      "A perfect smile can hide an impressive amount of irritation.",
      "All right. Let's make this one worth remembering.",
    },
  },
  OPP_PSYCHIC_TR = {
    first = {
      "I saw this rematch already. I didn't like the ending.",
      "{STRONGEST} was in the vision too. That's encouraging.",
      "The BEACON rang before I knew it would. Rude.",
      "Some futures go dark when you look too closely.",
      "I predicted you'd come back. I also predicted breakfast. One was harder.",
      "{STRONGEST} appears in every useful future I checked.",
      "Your first victory created several unpleasant branches.",
      "I tried not thinking about the rematch. That made it louder.",
      "There are outcomes I don't describe because naming them feels like inviting them.",
      "Let's choose a better future this time.",
    },
    later = {
      "Yes, yes. I knew you'd come back. Eventually that stops being impressive.",
      "{STRONGEST} is exactly where the vision put it.",
      "I changed the future. Or the plan. One of those is easier.",
      "There are outcomes I don't mention. Let's avoid those.",
      "The BEACON rang three seconds after I expected it. Disturbing.",
      "{STRONGEST} keeps appearing beside you in my dreams. Very inconsiderate.",
      "Our futures are becoming annoyingly repetitive.",
      "I stopped predicting whether we'd rematch and started predicting how tired I'd be.",
      "Some paths end suddenly. I prefer the ones with victory music.",
      "Fine. Let's make the vision useful for once.",
    },
  },
  OPP_ROCKER = {
    first = {
      "I turned the training up to eleven. It only went to ten.",
      "{STRONGEST} is ready to make some noise.",
      "Last battle had a terrible ending. I'm demanding an encore.",
      "Silence after a fight can be louder than the fight.",
      "I wrote a song about losing to you. It is not flattering to either of us.",
      "{STRONGEST} gets the solo this time.",
      "The first battle was all feedback and no rhythm.",
      "I practiced until the amp gave up before I did.",
      "Every loud room goes quiet eventually. That's the part people remember.",
      "Count us in. And try to stay on beat.",
    },
    later = {
      "Encore again? You're becoming a demanding audience.",
      "{STRONGEST} knows the set list now.",
      "I changed the arrangement. Same volume.",
      "Every song ends. Some just cut out mid-note.",
      "The BEACON has terrible tone. Effective hook, though.",
      "{STRONGEST} is tuned up. My ears are not.",
      "This rivalry needs a shorter chorus.",
      "I've played worse venues. None of them followed me around.",
      "A final note can hang in the room longer than anyone expects.",
      "One more track. No requests.",
    },
  },
  OPP_TAMER = {
    first = {
      "I trained harder. The Pokemon trained smarter.",
      "{STRONGEST} doesn't need a leash. That's either good or terrible.",
      "Last time I lost control of the battle. Not again.",
      "Fear is a leash too. Mine is shorter now.",
      "I worked on discipline. The team worked on ignoring my tone.",
      "{STRONGEST} knows exactly when to strike. I hope.",
      "Your first win made the whole routine look sloppy.",
      "Control isn't shouting louder. Took me longer than I'd like to learn that.",
      "Animals notice fear before people admit it.",
      "Stand still. This works better when only one of us is nervous.",
    },
    later = {
      "Back again? Good. Discipline needs distractions.",
      "{STRONGEST} knows exactly what I expect.",
      "I tightened the routine. Nobody enjoyed that.",
      "Control is easiest to notice right before you lose it.",
      "The BEACON keeps interrupting training. You are now part of training.",
      "{STRONGEST} doesn't flinch at your name anymore.",
      "I've learned not to confuse obedience with confidence.",
      "The team knows the drill. So do you.",
      "A cage can be open and still feel closed.",
      "Let's see which habit breaks first.",
    },
  },
  OPP_BIRD_KEEPER = {
    first = {
      "I changed the formation. {STRONGEST} gets the high ground.",
      "The birds saw you coming before the BEACON beeped.",
      "Last time clipped my wings. Figuratively. The Pokemon are fine.",
      "Anything that flies learns how far the ground can be.",
      "I trained at sunrise. The neighbors have opinions now.",
      "{STRONGEST} has been circling this rematch all morning.",
      "The flock scattered after our first battle. My confidence did too.",
      "I learned more from watching their formation than from my own notes.",
      "A shadow passes fast when you forget to look up.",
      "Keep your eyes on the sky. And the battle.",
    },
    later = {
      "You again? The flock is starting to recognize you.",
      "{STRONGEST} has been circling this rematch for days.",
      "New formation. Fewer dramatic dives.",
      "Sooner or later, everything airborne comes down.",
      "The BEACON chirps. The birds hate it. I understand them.",
      "{STRONGEST} has the wind today. Try not to stand under it.",
      "We've done this enough that the flock knows where to watch.",
      "I stopped calling these unexpected visits.",
      "Feathers fall softly. The thing they came from may not.",
      "All right. Formation up.",
    },
  },
  OPP_BLACKBELT = {
    first = {
      "I trained until my teacher told me to go home.",
      "{STRONGEST} and I don't need excuses. We need another round.",
      "Defeat showed me the gap. Training filled some of it.",
      "Pain passes. Bad habits wait for you.",
      "I repeated the basics until they stopped feeling basic.",
      "{STRONGEST} is calm. I am working on it.",
      "The first loss was clean. That made it harder to dismiss.",
      "Strength without control is just a faster mistake.",
      "A bruise fades. The lesson underneath can stay longer.",
      "Bow, breathe, battle.",
    },
    later = {
      "Again. Good. Technique rusts without pressure.",
      "{STRONGEST} is steadier now. So am I.",
      "No speeches. We've done this enough.",
      "A fighter learns which bruises are warnings and which are invitations.",
      "The BEACON interrupted meditation. Consider this the consequence.",
      "{STRONGEST} knows your pace. Change it if you can.",
      "Repetition reveals what talent hides.",
      "We've traded enough lessons to open a school.",
      "The body remembers impacts the mind pretends were nothing.",
      "Ready stance. Again.",
    },
  },
  OPP_SCIENTIST = {
    first = {
      "Your first victory has been classified as an inconvenient result.",
      "{STRONGEST} is the control group. You are the problem variable.",
      "I adjusted the experiment. Ethics were not a relevant variable.",
      "Failure is data. Enough data starts to look like a warning.",
      "I reproduced the conditions of our first battle except for the losing part.",
      "{STRONGEST} has exceeded projections. I quietly revised the projections.",
      "Your performance invalidated three assumptions and one lunch break.",
      "I have a hypothesis about why you won. It is extremely insulting to me.",
      "The lab labels dangerous samples. People are less conveniently labeled.",
      "Please remain still while I test whether preparation beats irritation.",
    },
    later = {
      "Excellent. Another trial. The sample size was bothering me.",
      "{STRONGEST} is performing above projections. I lowered the projections.",
      "I have revised the hypothesis from CAN WIN to SHOULD EVENTUALLY WIN.",
      "Repeated failure stops being surprising long before it stops being dangerous.",
      "The BEACON has become an uncontrolled variable. I dislike it personally.",
      "{STRONGEST} is reproducibly ready. My confidence is not statistically significant.",
      "We have enough data now. Unfortunately I still want more.",
      "I stopped calling these anomalies after the fourth one.",
      "Every experiment has a point where sensible people stop. Interesting, isn't it?",
      "Begin trial. Again.",
    },
  },
  OPP_COOLTRAINER_M = {
    first = {
      "I don't usually ask for second chances. I make them.",
      "{STRONGEST} is stronger. That's the only warning you get.",
      "I reviewed the battle once. Once was enough.",
      "Strong trainers remember every mistake because someone else will exploit it.",
      "You earned that win. Now earn it again.",
      "{STRONGEST} has been training for opponents exactly like you.",
      "I changed what needed changing and kept what worked.",
      "Excuses are wasted preparation time.",
      "Confidence is useful until it hides a weakness.",
      "No surprises. Just a better battle.",
    },
    later = {
      "Good. I was getting tired of easier battles.",
      "{STRONGEST} knows what you're capable of now.",
      "No excuses left. That's useful.",
      "A rivalry is just a habit with sharper consequences.",
      "You keep returning. Good opponents are hard to replace.",
      "{STRONGEST} improved because you forced it to.",
      "I know your patterns. You probably know mine.",
      "This stopped being about the BEACON a while ago.",
      "A strong opponent can become a measuring stick or a wall.",
      "Let's see which one you are today.",
    },
  },
  OPP_COOLTRAINER_F = {
    first = {
      "You earned the first win. Don't expect me to donate the second.",
      "{STRONGEST} is ready. Watch closely.",
      "I rebuilt the team around what you showed me.",
      "The dangerous mistake is the one you survive and decide was harmless.",
      "I remember every turn that mattered. There were more than I liked.",
      "{STRONGEST} is stronger because you gave us a reason.",
      "I don't need a dramatic speech. I need better execution.",
      "The first battle told me exactly where the weaknesses were.",
      "Good opponents expose things training alone cannot.",
      "Ready? I am.",
    },
    later = {
      "Again? Good. You're still worth preparing for.",
      "{STRONGEST} has an answer for you now.",
      "I keep improving because you keep showing up.",
      "Eventually one of us runs out of lessons.",
      "The BEACON is unnecessary at this point. I'd have recognized you anyway.",
      "{STRONGEST} knows the matchup. So do I.",
      "We've removed surprise from the equation. Skill remains.",
      "Every rematch narrows the gap somewhere.",
      "There is a point where rivalry becomes routine. Routine can still cut.",
      "Show me what changed.",
    },
  },
  OPP_GENTLEMAN = {
    first = {
      "I requested a rematch formally. The BEACON lacked stationery.",
      "{STRONGEST} is prepared. I have also brought better tea for afterward.",
      "One should accept defeat gracefully. One may still resent it privately.",
      "Manners are what remain when patience doesn't.",
      "I have had time to reflect. Regrettably, reflection did not count as victory.",
      "{STRONGEST} has trained diligently. I merely supervised with distinction.",
      "Your previous performance was excellent. I found that deeply inconvenient.",
      "A gentleman keeps his word, his composure, and ideally his winning record.",
      "Politeness does not require forgetting.",
      "Shall we proceed before the tea becomes undrinkable?",
    },
    later = {
      "Once more? Very well. Consistency is a virtue, even yours.",
      "{STRONGEST} remembers our previous engagement.",
      "I have prepared both a victory speech and a gracious silence.",
      "Civilized competition can still leave uncivilized thoughts.",
      "The BEACON's persistence is almost admirable. Almost.",
      "{STRONGEST} is prepared. I have stopped pretending this is spontaneous.",
      "We meet often enough that I may need to add you to the calendar.",
      "My staff has begun asking whether you are staying for dinner.",
      "Good breeding teaches restraint. It does not erase irritation.",
      "Very well. Another round, properly conducted.",
    },
  },
  OPP_CHANNELER = {
    first = {
      "The spirits said AGAIN. They were annoyingly specific.",
      "{STRONGEST} is not the only one standing with me.",
      "Your BEACON made something else answer first.",
      "Something in this place remembers your name. I didn't tell it.",
      "I asked whether I should accept. Three voices said yes. One laughed.",
      "{STRONGEST} has been restless since you returned to the area.",
      "The first battle left an echo here. It hasn't stopped.",
      "The dead are poor strategists but excellent listeners.",
      "Do not mind the cold spot behind you. It was there before. I think.",
      "Let us finish before whatever answered the BEACON gets closer.",
    },
    later = {
      "You returned. The room already knew.",
      "{STRONGEST} is ready. The others are merely watching.",
      "The spirits are taking bets now. This is becoming undignified.",
      "Every rematch leaves an echo. Yours are getting crowded.",
      "The BEACON rang. Something beneath the floor rang back.",
      "{STRONGEST} stopped looking at you and started looking behind you.",
      "One spirit insists we've fought this battle before today. I disagree.",
      "I no longer ask who is watching. It encourages answers.",
      "There are more footsteps after our battles than before them.",
      "Begin. And if you hear your name from the stairs, ignore it.",
    },
  },
}

-- The second JUGGLER id uses the same class identity and authored voice.
P.OPP_JUGGLER_X = P.OPP_JUGGLER

local GENERIC = {
  first = {
    "I wasn't expecting that BEACON to work. Let's not waste it.",
    "{STRONGEST} and I have unfinished business with you.",
    "I remember the first battle clearly enough.",
    "Second chances are only useful if you do something different with them.",
    "I trained after our last battle. You gave me a reason.",
    "{STRONGEST} is ready. That's enough introduction.",
    "You won once. I would like to know whether you can repeat it.",
    "I changed the parts of the plan that failed. There were several.",
    "A loss can fade or sharpen. Mine chose sharpen.",
    "The signal found me. Let's see what follows.",
  },
  later = {
    "You're back again. All right.",
    "{STRONGEST} recognizes you by now.",
    "We keep meeting like this. I keep training for it.",
    "Some rivalries get names. Ours just keeps getting rematches.",
    "The BEACON barely needed to ring this time.",
    "{STRONGEST} is stronger. You'll have noticed eventually.",
    "I stopped calling these surprise battles.",
    "We know enough about each other to skip the excuses.",
    "Repeated battles leave marks even when nobody can see them.",
    "Again, then. Let's make it count.",
  },
}

local function profile(classId)
  return P[classId] or GENERIC
end

function Dialogue.variants(classId, phase)
  local rows = profile(classId)[phase == "later" and "later" or "first"] or {}
  local out = {}
  for _, row in ipairs(rows) do out[#out + 1] = row end
  return out
end

local function substitute(text, vars)
  vars = vars or {}
  return (tostring(text or ""):gsub("{([A-Z_]+)}", function(key)
    local value = vars[key]
    return value == nil and key or tostring(value)
  end))
end

-- Gen-1 dialogue boxes are narrow. Author strings naturally, then wrap them
-- into two-line pages so dynamic Pokemon names cannot punch through the box.
function Dialogue.wrap(text, width, linesPerPage)
  width = width or 18
  linesPerPage = linesPerPage or 2
  local lines, line = {}, ""
  local function pushLongWord(word)
    while #word > width do
      lines[#lines + 1] = word:sub(1, width)
      word = word:sub(width + 1)
    end
    return word
  end
  for word in tostring(text or ""):gmatch("%S+") do
    if #word > width then
      if line ~= "" then lines[#lines + 1] = line; line = "" end
      word = pushLongWord(word)
    end
    if word ~= "" then
      if line == "" then
        line = word
      elseif #line + 1 + #word <= width then
        line = line .. " " .. word
      else
        lines[#lines + 1] = line
        line = word
      end
    end
  end
  if line ~= "" then lines[#lines + 1] = line end
  local out = {}
  for i, row in ipairs(lines) do
    out[#out + 1] = row
    if i < #lines then
      out[#out + 1] = (i % linesPerPage == 0) and "\f" or "\n"
    end
  end
  return table.concat(out)
end

function Dialogue.render(text, vars)
  return Dialogue.wrap(substitute(text, vars):upper())
end

function Dialogue.pick(classId, phase, vars, forcedIndex)
  local rows = Dialogue.variants(classId, phase)
  local index = tonumber(forcedIndex)
  if not index or index < 1 or index > #rows then
    if love and love.math and love.math.random then index = love.math.random(1, #rows)
    else index = math.random(1, #rows) end
  end
  return Dialogue.render(rows[index], vars), index
end

function Dialogue.supportedClasses()
  local out, seen = {}, {}
  for id, row in pairs(P) do
    if type(row) == "table" and not seen[id] then out[#out + 1] = id; seen[id] = true end
  end
  table.sort(out)
  return out
end

return Dialogue
