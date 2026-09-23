-- Authored Rocket incident content.
-- Core scheduling, persistence, actor spawning and Decoder UI live in
-- rocket_decoder.lua. New incidents should mostly be additions to this table.

local Incidents={}

Incidents.BADGES={
  "BOULDERBADGE","CASCADEBADGE","THUNDERBADGE","RAINBOWBADGE",
  "SOULBADGE","MARSHBADGE","VOLCANOBADGE","EARTHBADGE",
}

-- Named operatives own authored party tiers rather than borrowing an arbitrary
-- vanilla ROCKET party. The framework picks a tier from story/badge progress;
-- it deliberately does not rubber-band to the player's exact party level.
Incidents.OPERATIVES={
  ronnie={
    name="RONNIE",tagline="Talks first. Thinks later.",trainerId="OPP_DS_RONNIE",
    parties={
      {{species="RATTATA",level=7},{species="ZUBAT",level=7}},
      {{species="RATICATE",level=16},{species="ZUBAT",level=15}},
      {{species="RATICATE",level=25},{species="GOLBAT",level=24},{species="DROWZEE",level=24}},
      {{species="RATICATE",level=34},{species="GOLBAT",level=33},{species="HYPNO",level=34}},
    },
  },
  milo={
    name="MILO",tagline="Rocket's least enthusiastic employee.",trainerId="OPP_DS_MILO",
    parties={
      {{species="SANDSHREW",level=8},{species="DROWZEE",level=8}},
      {{species="DROWZEE",level=17},{species="MACHOP",level=16}},
      {{species="HYPNO",level=25},{species="MACHOKE",level=25}},
      {{species="HYPNO",level=34},{species="MACHOKE",level=34},{species="WEEZING",level=33}},
    },
  },
  cass={
    name="CASS",tagline="Competent enough to be dangerous.",trainerId="OPP_DS_CASS",
    parties={
      {{species="EKANS",level=9},{species="KOFFING",level=9}},
      {{species="ARBOK",level=18},{species="KOFFING",level=18},{species="ZUBAT",level=17}},
      {{species="ARBOK",level=27},{species="WEEZING",level=27},{species="GOLBAT",level=26}},
      {{species="ARBOK",level=36},{species="WEEZING",level=36},{species="GOLBAT",level=35}},
    },
  },
}

local function shipmentRonnie(env)
  env:meet("ronnie")
  local mem=env:memory("ronnie")
  if mem.last_battle=="loss" then
    env:say("RONNIE: OH. YOU.\fI REMEMBER THIS GOING\nVERY WELL FOR ME.\f...THAT SOUNDED LESS\nNERVOUS IN MY HEAD.")
  elseif mem.battle_wins>=2 then
    env:say("RONNIE: NO.\fNO, I KNOW HOW THIS\nGOES NOW.\fYOU SHOW UP. I SAY\nSOMETHING STUPID.\fTHEN I LOSE.")
  elseif mem.last_battle=="win" then
    env:say("RONNIE: YOU AGAIN.\fDO YOU JUST WALK\nAROUND LOOKING FOR\nCRIMES?")
  else
    env:say("RONNIE: STOP.\f...YOU'RE A KID.\fTHEY SENT ME TO GUARD\nA PROTOTYPE FROM A KID?\fNO. THAT CAN'T BE\nTHE ACTUAL BRIEF.")
  end
  env:say("RONNIE: THIS CRATE IS\nROCKET PROPERTY.\f...FORGET I SAID\nROCKET.")

  local choice=env:choose("RONNIE",{
    {label="ASK",value="inside"},
    {label="TAKE IT",value="take"},
    {label="RADIO",value="radio"},
    {label="BLUFF",value="bluff"},
    {label="LEAVE",value="leave"},
  })
  if choice=="leave" or not choice then
    env:say("RONNIE: RIGHT.\fGOOD.\fA COMPLETELY NORMAL\nCONVERSATION.")
    return
  elseif choice=="inside" then
    env:say("RONNIE: WHAT'S INSIDE?\fNOTHING YOU NEED.\fA PROTOTYPE.\f...I MEAN A BOX.\fA NORMAL BOX.")
    local follow=env:choose("RONNIE",{
      {label="PRESS",value="push"},
      {label="BACK OFF",value="leave"},
    })
    if follow~="push" then
      env:say("RONNIE: GOOD.\fLET'S BOTH FORGET THE\nPROTOTYPE PART.")
      return
    end
    env:say("RONNIE: NO.\fTHAT'S ENOUGH QUESTIONS.\fWE'RE DOING THE PART\nWITH POKEMON NOW.")
  elseif choice=="bluff" then
    if mem.flags.fooled then
      env:say("RONNIE: NO.\fI WROTE 'DO NOT GIVE\nCRATES TO CHILDREN'\fON MY HAND AFTER\nLAST TIME.")
    else
      env:say("RONNIE: THE BOSS SENT\nYOU?\f...THAT DOES SOUND LIKE\nSOMETHING HE'D DO.\fWAIT. WHICH BOSS?")
      local bluff=env:choose("RONNIE",{
        {label="SAY NOTHING",value="commit"},
        {label="DROP IT",value="leave"},
      })
      if bluff=="commit" then
        env:setOperativeFlag("ronnie","fooled",true)
        env:say("RONNIE: RIGHT.\fNEED TO KNOW.\fI RESPECT THAT.\fHERE. TAKE IT BEFORE\nI ASK A QUESTION.")
        if env:giveCargo(0) then
          env:finish("RESOLVED_ALTERNATE","Ronnie surrendered the prototype after a bluff.")
        end
        return
      end
      return
    end
  elseif choice=="radio" then
    env:setOperativeFlag("ronnie","radio_exposed",true)
    env:say("RONNIE: YOU HEARD THE\nRADIO?\fTHE WHOLE THING?\f...OH, I AM SO FIRED.\fACTUALLY, FIRST I'M\nGOING TO BATTLE YOU.")
  else
    env:say("RONNIE: I'M NOT JUST\nHANDING IT OVER.\fTHAT WOULD BE A VERY\nSHORT CAREER.")
  end

  local result=env:trainerBattle("ronnie")
  if result=="win" then
    env:say("RONNIE: ...THERE IT IS.\fTHE PART OF THE JOB I\nWAS WORRIED ABOUT.\fTAKE THE CRATE.\fI'M GOING TO PRACTICE\nNOT EXPLAINING THIS.")
    env:setPhase("reward")
  else
    env:finish("ROCKET_SUCCESS","Ronnie delivered the prototype shipment.")
  end
end

local function shipmentCrate(env)
  if env:phase()=="reward" then
    env:say("The crate is still\nsealed.\fA SILPH prototype label\nhas been scratched out.")
    if env:giveCargo(300) then
      env:finish("RESOLVED_WIN","The intercepted prototype shipment was recovered.")
    end
  else
    env:say("RONNIE: HEY.\fTHE CRATE IS THE ONE\nTHING YOU'RE DEFINITELY\nNOT SUPPOSED TO TOUCH.")
  end
end

local function cacheMilo(env)
  env:meet("milo")
  local mem=env:memory("milo")
  if mem.last_battle=="win" then
    env:say("MILO: I REMEMBER YOU.\fI ALSO REMEMBER HOW\nLAST TIME ENDED.\fSO I'M OPEN TO A LESS\nPHYSICAL DISCUSSION.")
  elseif mem.last_battle=="loss" then
    env:say("MILO: BACK AGAIN?\fI WAS HOPING OUR LAST\nMEETING HAD SETTLED\nTHE MATTER.")
  elseif mem.met>1 then
    env:say("MILO: YOU AGAIN.\fTHIS JOB HAS A VERY\nSPECIFIC KIND OF\nREPETITION.")
  else
    env:say("MILO: YOU'RE EARLY.\fOR I'M LATE.\fEITHER WAY, THAT'S\nGOING IN SOMEONE'S\nREPORT.")
  end
  env:say("MILO: THIS IS A DEAD DROP.\fYOU DIDN'T SEE IT.\nI DIDN'T SEE YOU.\fWE COULD BOTH HAVE A\nVERY SHORT DAY.")

  local choice=env:choose("MILO",{
    {label="TALK",value="talk"},
    {label="MOVE ASIDE",value="fight"},
    {label="LEAVE",value="leave"},
  })
  if choice=="leave" or not choice then
    env:say("MILO: FINALLY.\fA PLAN WITH NO\nPAPERWORK.")
    return
  end

  if choice=="talk" then
    if mem.last_battle=="win" then
      env:say("MILO: LAST TIME I DID\nTHIS BY THE BOOK,\fYOU PUT ME ON THE\nGROUND.\fSO HERE'S MY OFFER.\fYOU TAKE THE PROTOTYPE.\nI KEEP THE REST.\fWE BOTH LEAVE.")
      local follow=env:choose("MILO",{
        {label="AGREE",value="split"},
        {label="REFUSE",value="fight"},
        {label="LEAVE",value="leave"},
      })
      if follow=="split" then
        env:say("MILO: GOOD.\fA TRANSACTION IN WHICH\nNO ONE GETS KICKED.\fI COULD GET USED TO\nTHAT.")
        if env:giveCargo(100) then
          env:finish("RESOLVED_ALTERNATE","Milo traded the prototype for a quiet exit.")
        end
        return
      elseif follow~="fight" then
        return
      end
    else
      env:say("MILO: A DEAL?\fWE DON'T HAVE A DEAL.\fI DON'T KNOW YOU WELL\nENOUGH TO BET MY JOB\nON YOUR DISCRETION.")
      if mem.last_battle=="loss" then
        env:say("MILO: ESPECIALLY NOT\nAFTER LAST TIME.")
      end
      local follow=env:choose("MILO",{
        {label="INSIST",value="fight"},
        {label="LEAVE",value="leave"},
      })
      if follow~="fight" then return end
    end
  end

  env:say("MILO: ALL RIGHT.\fWE'LL DO THIS THE\nCOMPANY-POLICY WAY.")
  local result=env:trainerBattle("milo")
  if result=="win" then
    env:say("MILO: ALL RIGHT.\fTHE DROP IS YOURS.\fI'M WRITING 'FOUND\nEMPTY' AND GOING HOME.")
    env:setPhase("reward")
  else
    env:finish("ROCKET_SUCCESS","Milo collected the cache and cleared the drop.")
  end
end

local function cacheBox(env)
  if env:phase()=="reward" then
    env:say("The dead drop has been\nleft behind.")
  else
    env:say("A small container is\ntucked against the old\nforest marker.\fIt matches the decoded\ntransmission.")
    local c=env:choose("DEAD DROP",{
      {label="OPEN",value="open"},
      {label="LEAVE",value="leave"},
    })
    if c~="open" then return end
    env:meet("milo")
    local mem=env:memory("milo")
    if mem.last_battle=="win" then
      env:say("MILO: ...YOU FOUND IT\nFIRST.\fAND, GIVEN OUR HISTORY,\nI'M NOT GOING TO PRETEND\nI CAN TAKE IT BACK.")
    else
      env:say("MILO: ...THAT'S THE\nDROP.\fAND YOU'VE ALREADY\nOPENED IT.\fI'M MAKING A RARE\nPROFESSIONAL DECISION\nAND LEAVING.")
    end
  end
  if env:giveCargo(500) then
    env:finish("RESOLVED_WIN","The Rocket dead drop was found before it could be moved.")
  end
end

local function experimentCass(env)
  env:meet("cass")
  local mem=env:memory("cass")
  if mem.last_battle=="loss" then
    env:say("CASS: YOU CAME BACK.\fGOOD.\fI WAS BEGINNING TO\nTHINK THE FIRST TIME\nHAD TAUGHT YOU CAUTION.")
  elseif mem.flags.sabotaged then
    env:say("CASS: HANDS WHERE I CAN\nSEE THEM.\fI REMEMBER WHAT ONE\nSWITCH COST US.")
  elseif mem.last_battle=="win" then
    env:say("CASS: I KNOW WHO YOU ARE.\fTHIS TIME, YOU DON'T\nGET NEAR THE EQUIPMENT.")
  else
    env:say("CASS: STOP THERE.\fTHIS SITE IS CLOSED.\fSCIENTIST: TECHNICALLY,\nIT WAS NEVER OPEN.\fCASS: NOT NOW.")
  end

  local choice=env:choose("CASS",{
    {label="ASK",value="ask"},
    {label="MACHINE",value="check"},
    {label="CHALLENGE",value="fight"},
    {label="LEAVE",value="leave"},
  })
  if choice=="leave" or not choice then
    env:say("CASS: SENSIBLE.")
    return
  elseif choice=="ask" then
    env:say("CASS: A PROTOTYPE\nATTRACTOR.\fIT WAS SUPPOSED TO DRAW\nSTRONG SPECIMENS.\fSCIENTIST: IT IS DRAWING\nSPECIMENS VERY WELL.\fCASS: THEY'RE RATTATA.\fSCIENTIST: YES.\fA REMARKABLE NUMBER.")
    env:setIncidentFlag("observed",true)
    env:setStage(4)
    return
  elseif choice=="check" then
    if env:incidentFlag("observed") then
      env:say("One switch sits a notch\nbelow the marked\nfrequency.")
      return
    end
    env:say("CASS: DON'T TOUCH IT.\fSCIENTIST: ACTUALLY...\nLET THEM LOOK.\fCASS: WHY?\fSCIENTIST: BECAUSE THEY\nNOTICED THE SWITCH.")
    env:setIncidentFlag("observed",true)
    env:setStage(4)
    return
  end

  env:say("CASS: FINE.\fIF YOU WANT TO MAKE\nTHIS SIMPLE.")
  local result=env:trainerBattle("cass")
  if result=="win" then
    env:say("CASS: PACK IT UP.\fTHE TEST IS OVER.\fSCIENTIST: BECAUSE OF\nTHE CHILD?\fCASS: THAT WORD DOES NOT\nAPPEAR IN THE REPORT.")
    if env:giveCargo(400) then
      env:finish("RESOLVED_WIN","Cass abandoned the experiment and its prototype equipment.")
    end
  else
    env:finish("ROCKET_SUCCESS","Cass secured the experiment and moved the results.")
  end
end

local function experimentScientist(env)
  env:say("SCIENTIST: THE ATTRACTOR\nIS WORKING PERFECTLY.\fCASS: IT'S ATTRACTING\nRATTATA.\fSCIENTIST: I SAID\nWORKING.\fI DID NOT SAY\nCORRECTLY.")
  env:setIncidentFlag("observed",true)
  env:setStage(4)
end

local function experimentDevice(env)
  env:say("The prototype attractor\nhums at an unpleasant\nfrequency.")
  local observed=env:incidentFlag("observed")
  local rows={
    {label=observed and "RETUNE" or "OBSERVE",value=observed and "sabotage" or "observe"},
    {label="LEAVE",value="leave"},
  }
  local choice=env:choose("ATTRACTOR",rows)
  if choice=="leave" or not choice then return end
  if choice=="observe" then
    env:say("One switch is set a\nnotch below the marked\nfrequency.")
    env:setIncidentFlag("observed",true)
    env:setStage(4)
    return
  end

  env:meet("cass")
  env:setOperativeFlag("cass","sabotaged",true)
  env:say("You move the switch one\nnotch.\fThe machine SHRIEKS.\fCASS: DON'T-\fSCIENTIST: THAT'S THE\nCORRECT FREQUENCY.\fCASS: THEN WHY IS IT\nSCREAMING?")
  local result=env:wildBattle("RATTATA",{10,18,26,34})
  if result=="loss" then
    env:finish("ROCKET_SUCCESS","Rocket recovered the attractor after the experiment broke loose.")
    return
  end
  env:say("CASS: WE'RE DONE.\fSCIENTIST: SHOULD WE TAKE\nTHE ATTRACTOR?\fCASS: YOU CARRY IT.\fSCIENTIST: ...WE'RE DONE.")
  if env:giveCargo(150) then
    env:finish("RESOLVED_ALTERNATE","The attractor was retuned and Rocket abandoned the experiment.")
  end
end

Incidents.ALL={
  intercepted_shipment={
    id="intercepted_shipment",title="INTERCEPTED SHIPMENT",operative="ronnie",expiry=2500,
    minTrainerTier=2,
    prototypePool={"prism_scent","elusive_scent","mystery_lure","species_whistle","prototype_resonator","glitch_detector"},
    locations={{
      id="route5",mapId="ROUTE_5",
      unlockVisited={"CERULEAN_CITY"},
      regionMaps={"CERULEAN_CITY","ROUTE_5","UNDERGROUND_PATH_ROUTE_5"},
      anchor={x=17,y=27},
    }},
    transmissions={
      "ROCKET BAND TRANSMISSION\f???: YOU HAVE THE\nPACKAGE?\fRONNIE: YES.\f???: THEN STOP SAYING\n'PACKAGE' OVER RADIO.\fRONNIE: RIGHT.\fI HAVE THE...\nNOT-PACKAGE.",
      "SIGNAL QUALITY IMPROVED\f???: TAKE IT SOUTH.\nUSE THE QUIET ROUTE.\fRONNIE: THE ONE BY THE\nUNDERGROUND PATH?\f???: ...\fYES, RONNIE.\fTHE SECRET QUIET ROUTE\nYOU JUST NAMED.",
      "SIGNAL: VERY STRONG\fRONNIE: THERE'S A KID\nHERE.\f???: THEN ACT NORMAL.\fRONNIE: I AM.\f???: YOU'RE WHISPERING\nINTO THE RADIO.",
    },
    actors={
      {role="ronnie",name="DS_ROCKET_RONNIE",sprite="SPRITE_ROCKET",text="TEXT_DS_ROCKET_SHIPMENT_RONNIE",dx=0,dy=0,phases={active=true}},
      {role="crate",name="DS_ROCKET_SHIPMENT_CRATE",sprite="SPRITE_POKE_BALL",text="TEXT_DS_ROCKET_SHIPMENT_CRATE",dx=1,dy=0,phases={active=true,reward=true}},
    },
    interact={ronnie=shipmentRonnie,crate=shipmentCrate},
  },

  hidden_cache={
    id="hidden_cache",title="HIDDEN CACHE",operative="milo",expiry=2800,
    minTrainerTier=1,
    prototypePool={"prism_scent","elusive_scent","mystery_lure","species_whistle","prototype_resonator","safari_kit","glitch_detector"},
    locations={{
      id="forest",mapId="VIRIDIAN_FOREST",
      unlockVisited={"VIRIDIAN_CITY","PEWTER_CITY"},
      regionMaps={"VIRIDIAN_CITY","VIRIDIAN_FOREST","VIRIDIAN_FOREST_NORTH_GATE","VIRIDIAN_FOREST_SOUTH_GATE","PEWTER_CITY"},
      anchor={x=16,y=43},
    }},
    transmissions={
      "DROP CONFIRMED.\fNO CONTACT.\fMARKER IS STILL\nIN PLACE.\fSOURCE ESTIMATE:\nVIRIDIAN SECTOR.",
      "SIGNAL QUALITY IMPROVED\fMILO: YOU MOVED IT,\nRIGHT?\f???: NO.\fMILO: GREAT.\fSO EITHER IT'S STILL\nTHERE OR SOMEONE STOLE\nOUR STOLEN GOODS.",
      "LOCAL FRAGMENT\f???: USE THE OLD\nFOREST MARKER.\fMILO: WHICH OLD\nFOREST MARKER?\f???: THE ONE BY THE DROP.\fMILO: VERY HELPFUL.",
    },
    actors={
      {role="milo",name="DS_ROCKET_MILO",sprite="SPRITE_ROCKET",text="TEXT_DS_ROCKET_CACHE_MILO",dx=2,dy=0,phases={active=true}},
      {role="cache",name="DS_ROCKET_CACHE",sprite="SPRITE_POKE_BALL",text="TEXT_DS_ROCKET_CACHE_BOX",dx=0,dy=0,phases={active=true,reward=true}},
    },
    interact={milo=cacheMilo,cache=cacheBox},
  },

  illegal_experiment={
    id="illegal_experiment",title="ILLEGAL EXPERIMENT",operative="cass",expiry=3000,
    minTrainerTier=2,
    prototypePool={"prism_scent","elusive_scent","mystery_lure","species_whistle","prototype_resonator","glitch_detector"},
    locations={{
      id="rock",mapId="ROCK_TUNNEL_1F",
      unlockVisited={"VERMILION_CITY","LAVENDER_TOWN"},
      requiredItems={"CASCADEBADGE","HM_CUT"},
      regionMaps={"ROCK_TUNNEL_1F","ROUTE_9","ROUTE_10","LAVENDER_TOWN"},
      anchor={x=15,y=4},
    }},
    transmissions={
      "CASS: TEST SUBJECT\nSECURED.\fSCIENTIST: READINGS?\fCASS: INCREASING.\fSCIENTIST: THAT ISN'T\nPOSSIBLE.\fCASS: THEN COME LOOK\nAT IT.",
      "SIGNAL QUALITY IMPROVED\fSCIENTIST: KEEP\nCIVILIANS AWAY.\fCASS: THERE ARE NO\nCIVILIANS.\fSCIENTIST: WHAT ABOUT\nTHE CHILD?\fCASS: ...WHAT CHILD?",
      "SIGNAL: VERY STRONG\fSCIENTIST: THE ATTRACTOR\nIS ABOVE SPEC.\fCASS: THEN WHY ARE THERE\nSO MANY RATTATA?",
      "ADDITIONAL DECODE\fSCIENTIST: THE FREQUENCY\nSWITCH IS...\f...\fONE NOTCH LOW.\fCASS: DO NOT SAY THAT\nOVER RADIO.",
    },
    actors={
      {role="cass",name="DS_ROCKET_CASS",sprite="SPRITE_ROCKET",text="TEXT_DS_ROCKET_EXPERIMENT_CASS",dx=0,dy=0,phases={active=true}},
      {role="scientist",name="DS_ROCKET_SCIENTIST",sprite="SPRITE_SUPER_NERD",text="TEXT_DS_ROCKET_EXPERIMENT_SCI",dx=2,dy=0,phases={active=true}},
      {role="device",name="DS_ROCKET_ATTRACTOR",sprite="SPRITE_POKE_BALL",text="TEXT_DS_ROCKET_EXPERIMENT_DEVICE",dx=1,dy=1,phases={active=true}},
    },
    interact={cass=experimentCass,scientist=experimentScientist,device=experimentDevice},
  },
}

Incidents.ORDER={"intercepted_shipment","hidden_cache","illegal_experiment"}

return Incidents
