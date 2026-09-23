-- Trainer Beacon rematch dialogue.
--
-- Every supported ordinary Gen 1 trainer type gets exactly ten first-rematch
-- and ten repeat-rematch variants: six shared structural lines plus four
-- class-authored lines.  The class lines are where most of the personality,
-- humour, and occasional darker edge lives. Unknown/modded classes use the
-- GENERIC profile rather than failing.

local Dialogue = {}

local FIRST_COMMON = {
  "So the BEACON really works. {STRONGEST} and I are ready.",
  "You won once. I kept thinking about why.",
  "I changed the plan since last time. Let's test it.",
  "No surprise this time. You asked for a rematch, and you got one.",
  "{STRONGEST} has been waiting for you.",
  "Let's find out whether your first win was skill or timing.",
}

local LATER_COMMON = {
  "Again? Fine. {STRONGEST} knows the routine.",
  "At this point the BEACON should know us by name.",
  "I changed the plan again. One of these plans has to work.",
  "Same place, same trainer, different fight.",
  "You keep coming back. I respect that more than I expected.",
  "{STRONGEST} is stronger. So am I. Probably.",
}

local P = {
  OPP_YOUNGSTER = {
    first = {
      "I trained all week. Well, most of Tuesday.",
      "My {STRONGEST} says we're ready. I chose to believe it.",
      "I told everyone I'd win the rematch. Please don't make this weird.",
      "Last time hurt my pride more than my Pokemon. Somehow that's worse.",
    },
    later = {
      "You're back? Good. I finally stopped explaining the last one.",
      "My {STRONGEST} has a strategy. I have snacks. We're prepared.",
      "If I lose again, I'm calling this advanced training.",
      "One day I'll be the trainer people warn kids about. Not today, apparently.",
    },
  },
  OPP_BUG_CATCHER = {
    first = {
      "I brought extra ANTIDOTES. Mostly for my pride.",
      "My {STRONGEST} came out stronger. I came out itchier.",
      "The forest eats weak things. Today it gets to watch.",
      "Every cocoon opens eventually. So does every grudge.",
    },
    later = {
      "I upgraded my net. It still doesn't catch excuses.",
      "{STRONGEST} molted. I just got more stubborn.",
      "The bugs don't remember losing. Lucky them.",
      "Keep coming back. The forest has room for another bad memory.",
    },
  },
  OPP_LASS = {
    first = {
      "I practiced a whole speech for this. The BEACON ruined the timing.",
      "{STRONGEST} is ready. I am choosing to look equally ready.",
      "I fixed my team and my attitude. One of those was harder.",
      "I remember exactly how you won. That's the annoying part.",
    },
    later = {
      "Again? At least give me time to invent a better excuse.",
      "{STRONGEST} recognizes you. That little glare is new.",
      "I'm running out of things to blame besides you.",
      "Some losses fade. Yours keep getting appointments.",
    },
  },
  OPP_SAILOR = {
    first = {
      "I've fought storms meaner than you. Storms don't use POTIONS, though.",
      "{STRONGEST} found its sea legs. I never lost mine.",
      "A rematch beats scrubbing the deck. Barely.",
      "The sea teaches one lesson: anything can disappear over the horizon.",
    },
    later = {
      "Back aboard? You must really hate dry land.",
      "{STRONGEST} is ready to make waves. Yes, I know how that sounded.",
      "I've tied knots less complicated than our battle record.",
      "The ocean doesn't keep score. I do.",
    },
  },
  OPP_JR_TRAINER_M = {
    first = {
      "I reviewed every mistake. There were enough for a full lesson.",
      "{STRONGEST} and I drilled this rematch until it stopped being fun.",
      "Coach said stay focused. The BEACON apparently counts as focus.",
      "Losing once is instruction. Losing twice would be a habit.",
    },
    later = {
      "Another rematch. Good. Repetition builds discipline.",
      "{STRONGEST} knows your tricks now. I wrote them down.",
      "I have a new plan and fewer excuses.",
      "Eventually practice stops feeling like practice and starts feeling personal.",
    },
  },
  OPP_JR_TRAINER_F = {
    first = {
      "I studied the battle afterward. You were irritatingly educational.",
      "{STRONGEST} is sharper now. So is the rest of the team.",
      "I made a training schedule. It has your name under TEST DAY.",
      "A clean loss still leaves a mark. Let's see what a clean win does.",
    },
    later = {
      "Good timing. We just finished practicing how not to lose to you.",
      "{STRONGEST} learned the routine. I changed it anyway.",
      "My notes on you need another page.",
      "Some lessons only stick when they hurt your pride.",
    },
  },
  OPP_POKEMANIAC = {
    first = {
      "I've been researching your team. Normal amount. Completely normal.",
      "{STRONGEST} and I have theories about you. Mostly unflattering ones.",
      "The BEACON found me? Excellent. Saves me looking for you.",
      "People call obsession unhealthy right up until it starts winning battles.",
    },
    later = {
      "You're back! Great. My notes were becoming dangerously hypothetical.",
      "{STRONGEST} remembers you. I have charts proving it.",
      "I revised the matchup table. And the backup matchup table.",
      "There is a point where research becomes fixation. We passed it two rematches ago.",
    },
  },
  OPP_SUPER_NERD = {
    first = {
      "I recalculated everything. The calculator asked for a break.",
      "According to my model, {STRONGEST} wins this. Please don't introduce new data.",
      "I corrected the obvious error: assuming you'd be easy.",
      "Failure is data. Enough data starts to look like a warning.",
    },
    later = {
      "New model. Same opponent. Statistically this has to work eventually.",
      "{STRONGEST} is operating within improved parameters. I am not.",
      "I added a margin of error. It has your name on it.",
      "The numbers stopped being comforting a while ago.",
    },
  },
  OPP_HIKER = {
    first = {
      "I climbed a mountain to train. Then I remembered the Pokemon did most of the work.",
      "{STRONGEST} is tougher now. My knees are not.",
      "You beat me once. Uphill both ways, somehow.",
      "The mountain keeps every footprint until the weather decides otherwise.",
    },
    later = {
      "You again? Fine. I needed an excuse to stop walking.",
      "{STRONGEST} trained on rock. I trained on sandwiches.",
      "At this point you're part of the route.",
      "Rock wears down slowly. So do people.",
    },
  },
  OPP_BIKER = {
    first = {
      "The BEACON beeped at me. I almost threw it in a ditch.",
      "{STRONGEST} is tuned up. I'm still making that everyone else's problem.",
      "Last time was a bad turn. This time I know the road.",
      "Roads don't care who gets back up. I do. Unfortunately.",
    },
    later = {
      "Again? You collect rematches like road rash.",
      "{STRONGEST} is louder now. Somehow.",
      "I know this road and I know your tricks.",
      "Keep pushing your luck. Every road ends somewhere.",
    },
  },
  OPP_BURGLAR = {
    first = {
      "A gadget that calls people back? That's worth stealing after the battle.",
      "{STRONGEST} is ready. And no, you didn't see where I got the training gear.",
      "I learned from last time. Mostly which exits not to use.",
      "Dark rooms teach you things daylight politely avoids.",
    },
    later = {
      "You again? This is becoming terrible for my professional image.",
      "{STRONGEST} is legit. The rest of my story is none of your business.",
      "I changed the plan. Fewer alarms this time.",
      "Locks aren't the only things that break if you keep testing them.",
    },
  },
  OPP_ENGINEER = {
    first = {
      "I fixed the plan. The plan now has fewer exposed wires.",
      "{STRONGEST} passed inspection. I waived several standards.",
      "The BEACON's signal is sloppy. Effective, though.",
      "Machines fail cleanly. People usually make more noise.",
    },
    later = {
      "I rebuilt the strategy. Again. Please stop creating maintenance work.",
      "{STRONGEST} is calibrated for this exact problem: you.",
      "If this fails, I'm blaming signal interference.",
      "Every system has a breaking point. Testing is how you find it.",
    },
  },
  OPP_JUGGLER = {
    first = {
      "Good news: I dropped fewer balls in practice. Bad news: Pokemon aren't balls.",
      "{STRONGEST} is the one thing I refuse to juggle.",
      "I can keep four things in the air. Winning should be one of them.",
      "The trick is smiling while everything is one mistake from the floor.",
    },
    later = {
      "Back again? Fine. Add one more thing to the routine.",
      "{STRONGEST} knows the cue. I hope I do.",
      "If I lose, I'm calling it performance art.",
      "Eventually every act ends. The audience just doesn't know when.",
    },
  },
  OPP_FISHER = {
    first = {
      "I caught nothing all morning, so apparently you're the day's big one.",
      "{STRONGEST} took the bait. Now let's see if you do.",
      "I had hours to think about that loss. Fishing gives you too much time.",
      "Deep water keeps what it gets. Let's stay on shore.",
    },
    later = {
      "You again? Better bite than anything in this water.",
      "{STRONGEST} is ready. The fish still aren't.",
      "I changed bait, line, and battle plan. Something has to work.",
      "Still water looks harmless. That's usually when it's deepest.",
    },
  },
  OPP_SWIMMER = {
    first = {
      "I trained while you stayed dry. Unfair advantage, really.",
      "{STRONGEST} is warmed up. I am literally already wet.",
      "Last battle sank fast. This one gets a better start.",
      "Water closes over mistakes quickly. People don't.",
    },
    later = {
      "Back for another lap? Try to keep up.",
      "{STRONGEST} is ready. I didn't even need a towel this time.",
      "I know your rhythm now. Every swimmer has one.",
      "You can fight a current for a long time before noticing how far it carried you.",
    },
  },
  OPP_CUE_BALL = {
    first = {
      "Last time was a scratch. This time I call the shot.",
      "{STRONGEST} is lined up. Don't move.",
      "The BEACON wants a rematch? Rack 'em up.",
      "Everybody acts tough until the table goes quiet.",
    },
    later = {
      "Again? You're really leaning on this table.",
      "{STRONGEST} has the angle now.",
      "Same game. Better break.",
      "Keep taking shots. Eventually something important drops.",
    },
  },
  OPP_GAMBLER = {
    first = {
      "I don't chase losses. Usually. Today is apparently special.",
      "I'm putting everything on {STRONGEST}. Figuratively. Mostly.",
      "The odds were bad last time. I blame the odds.",
      "Luck is comforting right up until it starts remembering your name.",
    },
    later = {
      "Double or nothing stopped making sense three battles ago.",
      "{STRONGEST} is my safest bet. That says more about me than it should.",
      "The house always wins. I need to find a house.",
      "Every losing streak ends. So does every lucky one.",
    },
  },
  OPP_BEAUTY = {
    first = {
      "I changed my strategy. The hair was already perfect.",
      "{STRONGEST} is ready, and yes, we coordinated.",
      "Losing was ugly. I fixed what I could.",
      "A smile is useful. People stop watching your hands.",
    },
    later = {
      "Again? Fine. At least this lighting is decent.",
      "{STRONGEST} looks confident. I taught that part personally.",
      "I refuse to make losing to you part of my look.",
      "Pretty things can still have sharp edges.",
    },
  },
  OPP_PSYCHIC_TR = {
    first = {
      "I saw this rematch already. I didn't like the ending.",
      "{STRONGEST} was in the vision too. That's encouraging.",
      "The BEACON rang before I knew it would. Rude.",
      "Some futures go dark when you look too closely.",
    },
    later = {
      "Yes, yes. I knew you'd come back. Eventually that stops being impressive.",
      "{STRONGEST} is exactly where the vision put it.",
      "I changed the future. Or the plan. One of those is easier.",
      "There are outcomes I don't mention. Let's avoid those.",
    },
  },
  OPP_ROCKER = {
    first = {
      "I turned the training up to eleven. It only went to ten.",
      "{STRONGEST} is ready to make some noise.",
      "Last battle had a terrible ending. I'm demanding an encore.",
      "Silence after a fight can be louder than the fight.",
    },
    later = {
      "Encore again? You're becoming a demanding audience.",
      "{STRONGEST} knows the set list now.",
      "I changed the arrangement. Same volume.",
      "Every song ends. Some just cut out mid-note.",
    },
  },
  OPP_TAMER = {
    first = {
      "I trained harder. The Pokemon trained smarter.",
      "{STRONGEST} doesn't need a leash. That's either good or terrible.",
      "Last time I lost control of the battle. Not again.",
      "Fear is a leash too. Mine is shorter now.",
    },
    later = {
      "Back again? Good. Discipline needs distractions.",
      "{STRONGEST} knows exactly what I expect.",
      "I tightened the routine. Nobody enjoyed that.",
      "Control is easiest to notice right before you lose it.",
    },
  },
  OPP_BIRD_KEEPER = {
    first = {
      "I changed the formation. {STRONGEST} gets the high ground.",
      "The birds saw you coming before the BEACON beeped.",
      "Last time clipped my wings. Figuratively. The Pokemon are fine.",
      "Anything that flies learns how far the ground can be.",
    },
    later = {
      "You again? The flock is starting to recognize you.",
      "{STRONGEST} has been circling this rematch for days.",
      "New formation. Fewer dramatic dives.",
      "Sooner or later, everything airborne comes down.",
    },
  },
  OPP_BLACKBELT = {
    first = {
      "I trained until my teacher told me to go home.",
      "{STRONGEST} and I don't need excuses. We need another round.",
      "Defeat showed me the gap. Training filled some of it.",
      "Pain passes. Bad habits wait for you.",
    },
    later = {
      "Again. Good. Technique rusts without pressure.",
      "{STRONGEST} is steadier now. So am I.",
      "No speeches. We've done this enough.",
      "A fighter learns which bruises are warnings and which are invitations.",
    },
  },
  OPP_SCIENTIST = {
    first = {
      "Your first victory has been classified as an inconvenient result.",
      "{STRONGEST} is the control group. You are the problem variable.",
      "I adjusted the experiment. Ethics were not a relevant variable.",
      "Failure is data. Enough data starts to look like a warning.",
    },
    later = {
      "Excellent. Another trial. The sample size was bothering me.",
      "{STRONGEST} is performing above projections. I lowered the projections.",
      "I have revised the hypothesis from CAN WIN to SHOULD EVENTUALLY WIN.",
      "Repeated failure stops being surprising long before it stops being dangerous.",
    },
  },
  OPP_COOLTRAINER_M = {
    first = {
      "I don't usually ask for second chances. I make them.",
      "{STRONGEST} is stronger. That's the only warning you get.",
      "I reviewed the battle once. Once was enough.",
      "Strong trainers remember every mistake because someone else will exploit it.",
    },
    later = {
      "Good. I was getting tired of easier battles.",
      "{STRONGEST} knows what you're capable of now.",
      "No excuses left. That's useful.",
      "A rivalry is just a habit with sharper consequences.",
    },
  },
  OPP_COOLTRAINER_F = {
    first = {
      "You earned the first win. Don't expect me to donate the second.",
      "{STRONGEST} is ready. Watch closely.",
      "I rebuilt the team around what you showed me.",
      "The dangerous mistake is the one you survive and decide was harmless.",
    },
    later = {
      "Again? Good. You're still worth preparing for.",
      "{STRONGEST} has an answer for you now.",
      "I keep improving because you keep showing up.",
      "Eventually one of us runs out of lessons.",
    },
  },
  OPP_GENTLEMAN = {
    first = {
      "I requested a rematch formally. The BEACON lacked stationery.",
      "{STRONGEST} is prepared. I have also brought better tea for afterward.",
      "One should accept defeat gracefully. One may still resent it privately.",
      "Manners are what remain when patience doesn't.",
    },
    later = {
      "Once more? Very well. Consistency is a virtue, even yours.",
      "{STRONGEST} remembers our previous engagement.",
      "I have prepared both a victory speech and a gracious silence.",
      "Civilized competition can still leave uncivilized thoughts.",
    },
  },
  OPP_CHANNELER = {
    first = {
      "The spirits said AGAIN. They were annoyingly specific.",
      "{STRONGEST} is not the only one standing with me.",
      "Your BEACON made something else answer first.",
      "Something in this place remembers your name. I didn't tell it.",
    },
    later = {
      "You returned. The room already knew.",
      "{STRONGEST} is ready. The others are merely watching.",
      "The spirits are taking bets now. This is becoming undignified.",
      "Every rematch leaves an echo. Yours are getting crowded.",
    },
  },
}

P.OPP_JUGGLER_X = P.OPP_JUGGLER

local GENERIC = {
  first = {
    "I wasn't expecting that BEACON to work. Let's not waste it.",
    "{STRONGEST} and I have unfinished business with you.",
    "I remember the first battle clearly enough.",
    "Second chances are only useful if you do something different with them.",
  },
  later = {
    "You're back again. All right.",
    "{STRONGEST} recognizes you by now.",
    "We keep meeting like this. I keep training for it.",
    "Some rivalries get names. Ours just keeps getting rematches.",
  },
}

local function profile(classId)
  return P[classId] or GENERIC
end

local function append(out, rows)
  for _, row in ipairs(rows or {}) do out[#out + 1] = row end
end

function Dialogue.variants(classId, phase)
  local out = {}
  if phase == "later" then
    append(out, LATER_COMMON)
    append(out, profile(classId).later)
  else
    append(out, FIRST_COMMON)
    append(out, profile(classId).first)
  end
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
  for word in tostring(text or ""):gmatch("%S+") do
    if line == "" then
      line = word
    elseif #line + 1 + #word <= width then
      line = line .. " " .. word
    else
      lines[#lines + 1] = line
      line = word
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
    -- JUGGLER_X aliases the same profile but remains a real class id.
    if type(row) == "table" and not seen[id] then out[#out + 1] = id; seen[id] = true end
  end
  table.sort(out)
  return out
end

return Dialogue
