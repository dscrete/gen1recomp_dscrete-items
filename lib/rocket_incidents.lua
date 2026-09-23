-- Authored Rocket incident content.
-- Core scheduling, persistence, actor spawning and Decoder UI live in
-- rocket_decoder.lua. New incidents should mostly be additions to this table.

local Incidents={}

Incidents.OPERATIVES={
  ronnie={name="RONNIE",tagline="Talks first. Thinks later."},
  milo={name="MILO",tagline="Rocket's least enthusiastic employee."},
  cass={name="CASS",tagline="Competent enough to be dangerous."},
}

local function shipmentRonnie(env)
  env:meet("ronnie")
  local mem=env:memory("ronnie")
  if mem.rocket_wins>0 then
    env:say("RONNIE: OH!\nIT'S YOU.\fI'VE ACTUALLY WON\nTHIS MATCHUP BEFORE.\fI'M NOT SAYING I'M\nCONFIDENT.\fBUT STATISTICALLY,\nTHIS ISN'T HOPELESS.")
  elseif mem.player_wins>=2 then
    env:say("RONNIE: WHY ARE YOU\nALWAYS HERE?\fDON'T YOU HAVE\nSCHOOL?")
  elseif mem.player_wins>0 then
    env:say("RONNIE: YOU AGAIN.\fDO YOU JUST WALK\nAROUND LOOKING FOR\nCRIMES?")
  else
    env:say("RONNIE: HEY.\f...\fYOU'RE A CHILD.\fI'M CURRENTLY BEING\nINTERCEPTED BY A CHILD.\fTHIS IS GOING TO LOOK\nTERRIBLE ON MY REPORT.")
  end
  env:say("RONNIE: THIS CRATE IS\nCOMPLETELY LEGITIMATE.\fIT'S FULL OF...\fOFFICE SUPPLIES.")

  local choice=env:choose("RONNIE",{
    {label="HAND IT OVER",value="take"},
    {label="WHAT'S INSIDE?",value="inside"},
    {label="BOSS SENT ME",value="bluff"},
    {label="I HEARD RADIO",value="radio"},
    {label="LEAVE",value="leave"},
  })
  if choice=="leave" or not choice then
    env:say("RONNIE: GREAT.\nGOOD TALK.")
    return
  elseif choice=="inside" then
    env:say("RONNIE: NOTHING IMPORTANT.\fCERTAINLY NOT A\nPROTOTYPE-\f...\fI SHOULD STOP TALKING.")
    local follow=env:choose("THE CRATE",{
      {label="KEEP ASKING",value="push"},
      {label="BACK OFF",value="leave"},
    })
    if follow~="push" then env:say("RONNIE: EXCELLENT\nDECISION."); return end
    env:say("RONNIE: NOPE. THAT'S IT.\nWE'RE BATTLING NOW.")
  elseif choice=="bluff" then
    if mem.flags.fooled then
      env:say("RONNIE: NICE TRY.\fYOU'RE NOT DOING THAT\n'MY BOSS SENT ME'\nTHING AGAIN.")
    else
      env:say("RONNIE: THE BOSS SENT-\nWAIT.\fHE DIDN'T SAY ANYTHING\nABOUT A KID.\f...\fBUT HE ALSO SAID NOT\nTO ASK QUESTIONS.")
      local bluff=env:choose("RONNIE",{
        {label="HAND IT OVER",value="commit"},
        {label="NEVER MIND",value="leave"},
      })
      if bluff=="commit" then
        env:setOperativeFlag("ronnie","fooled",true)
        env:say("RONNIE: FINE.\fIF THIS IS A TEST,\nI PASSED IT.")
        if env:giveCargo(0) then
          env:finish("RESOLVED_ALTERNATE","Ronnie surrendered the prototype after a bluff.")
        end
        return
      end
      return
    end
  elseif choice=="radio" then
    env:setOperativeFlag("ronnie","radio_exposed",true)
    env:say("RONNIE: YOU HEARD THAT?\fTHE WHOLE THING?\f...\fOH, I AM SO FIRED.\fACTUALLY, FIRST I'M\nGOING TO BATTLE YOU.")
  else
    env:say("RONNIE: I CAN'T JUST\nHAND OVER ROCKET PROPERTY!\fDO YOU KNOW WHAT\nTHEY'D DO TO ME?\f...\fACTUALLY, YOU DON'T.\nAND I'M NOT TELLING.")
  end

  local result=env:trainerBattle(5)
  if result=="win" then
    env:say("RONNIE: OH, COME ON.\fTHEY GAVE ME ONE JOB.\fYOU KNOW YOU'RE TAKING\nTHIS FROM TEAM ROCKET,\nRIGHT?\fWE'RE CRIMINALS.\f...\fTHAT SOUNDED MORE\nTHREATENING IN MY HEAD.")
    env:setPhase("reward")
  else
    env:finish("ROCKET_SUCCESS","Ronnie delivered the prototype shipment.")
  end
end

local function shipmentCrate(env)
  if env:phase()=="reward" then
    env:say("The Rocket crate is\nstill sealed.\fA SILPH prototype label\nhas been scratched out.")
    if env:giveCargo(300) then env:finish("RESOLVED_WIN","The intercepted prototype shipment was recovered.") end
  else
    env:say("RONNIE: HEY!\fDON'T TOUCH THE\nNOT-PACKAGE!")
  end
end

local function cacheMilo(env)
  env:meet("milo")
  local mem=env:memory("milo")
  if mem.rocket_wins>0 then
    env:say("MILO: YOU AGAIN.\fFOR WHAT IT'S WORTH,\nLAST TIME WAS THE BEST\nSHIFT I'VE HAD ALL MONTH.")
  elseif mem.player_wins>0 then
    env:say("MILO: OH, GOOD.\fMY FAVORITE WORKPLACE\nHAZARD.")
  else
    env:say("MILO: YOU KNOW WHAT'S\nREALLY IMPRESSIVE?\fI'VE BEEN SENT TO HIDE\nSOMETHING THAT WAS\nALREADY HIDDEN.")
  end
  env:say("MILO: LOOK, KID.\fI DON'T WANT TO FIGHT.\nYOU DON'T WANT TO FIGHT.\fMY BOSS, UNFORTUNATELY,\nIS VERY PRO-FIGHTING.")
  local choice=env:choose("MILO",{
    {label="WHERE'S CACHE?",value="ask"},
    {label="FIGHT",value="fight"},
    {label="WALK AWAY",value="leave"},
  })
  if choice=="leave" or not choice then env:say("MILO: FINALLY.\nA SENSIBLE PERSON."); return end
  if choice=="ask" then
    env:say("MILO: HYPOTHETICALLY?\fSOMEWHERE NEAR THE\nMARKER IN THE MESSAGE.\fALSO HYPOTHETICALLY,\nI'M TIRED OF STANDING\nNEXT TO IT.")
    local follow=env:choose("MILO",{
      {label="SPLIT IT",value="split"},
      {label="NO DEAL",value="fight"},
      {label="LEAVE",value="leave"},
    })
    if follow=="split" then
      env:say("MILO: YOU TAKE THE\nPROTOTYPE.\fI KEEP THE REST.\fTHAT WAY WE'RE BOTH\nONLY PARTLY IN TROUBLE.")
      if env:giveCargo(100) then env:finish("RESOLVED_ALTERNATE","Milo traded the prototype for a quiet exit.") end
      return
    elseif follow~="fight" then return end
  end
  env:say("MILO: RIGHT.\fAPPARENTLY WE'RE DOING\nTHE COMPANY-POLICY\nVERSION.")
  local result=env:trainerBattle(5)
  if result=="win" then
    env:say("MILO: FINE.\fTHE CACHE IS YOURS.\fI'M PUTTING THIS DOWN\nAS 'LOGISTICS FAILURE.'")
    env:setPhase("reward")
  else
    env:finish("ROCKET_SUCCESS","Milo collected the cache and cleared the drop.")
  end
end

local function cacheBox(env)
  if env:phase()=="reward" then
    env:say("The dead drop has been\nleft behind.")
  else
    env:say("A Rocket dead drop.\fThe marker matches the\ndecoded transmission.")
    local c=env:choose("HIDDEN CACHE",{{label="OPEN IT",value="open"},{label="LEAVE",value="leave"}})
    if c~="open" then return end
    env:meet("milo")
    env:say("MILO: ...\fYOU FOUND IT FIRST.\fTHAT SAVES ME A LOT OF\nPAPERWORK AND CREATES\nA DIFFERENT KIND.")
  end
  if env:giveCargo(500) then env:finish("RESOLVED_WIN","The Rocket dead drop was found before it could be moved.") end
end

local function experimentCass(env)
  env:meet("cass")
  local mem=env:memory("cass")
  if mem.rocket_wins>0 then
    env:say("CASS: YOU'RE PERSISTENT.\fI'LL GIVE YOU THAT.\fNOT SUCCESSFUL.\nBUT PERSISTENT.")
  elseif mem.flags.sabotaged then
    env:say("CASS: I CHECKED THE\nMACHINE THREE TIMES\nAFTER LAST TIME.\fYOU MOVED ONE SWITCH.")
  elseif mem.player_wins>0 then
    env:say("CASS: YOU ALWAYS DO THIS\nTHE LOUD WAY, DON'T YOU?")
  else
    env:say("CASS: SO YOU'RE THE CHILD\nTHE RADIO KEEPS\nMENTIONING.")
  end
  local choice=env:choose("CASS",{
    {label="CHALLENGE",value="fight"},
    {label="WHAT HAPPENED?",value="ask"},
    {label="CHECK MACHINE",value="check"},
    {label="LEAVE",value="leave"},
  })
  if choice=="leave" or not choice then env:say("CASS: SMARTER THAN THE\nREPORTS SUGGEST."); return
  elseif choice=="ask" then
    env:say("CASS: IT WAS BUILT TO\nATTRACT STRONG POKEMON.\fIT HAS INSTEAD ATTRACTED\nRATTATA.\fAN IMPRESSIVE NUMBER\nOF RATTATA.")
    env:setIncidentFlag("observed",true); env:setStage(4); return
  elseif choice=="check" then
    if env:incidentFlag("observed") then
      env:say("One frequency switch is\nset one notch low.\fThe machine is amplifying\nthe wrong signal.")
      return
    end
    env:say("CASS: DON'T TOUCH THAT.\fSCIENTIST: ACTUALLY-\nLET THE KID LOOK.\fCASS: WHY?\fSCIENTIST: BECAUSE THE\nKID NOTICED THE SWITCH.")
    env:setIncidentFlag("observed",true); env:setStage(4); return
  end

  env:say("CASS: FINE.\fLET'S SEE IF THE REPORTS\nEXAGGERATED.")
  local result=env:trainerBattle(5)
  if result=="win" then
    env:say("CASS: PACK IT UP.\fTHE TEST IS COMPROMISED.\fSCIENTIST: BY THE CHILD?\fCASS: DO NOT PUT THAT\nIN THE REPORT.")
    if env:giveCargo(400) then env:finish("RESOLVED_WIN","Cass abandoned the experiment and its prototype equipment.") end
  else
    env:finish("ROCKET_SUCCESS","Cass secured the experiment and moved the results.")
  end
end

local function experimentScientist(env)
  env:say("SCIENTIST: THE ATTRACTOR\nIS WORKING PERFECTLY.\fCASS: IT'S ATTRACTING\nRATTATA.\fSCIENTIST: I SAID\nWORKING.\fI DID NOT SAY\nCORRECTLY.")
  env:setIncidentFlag("observed",true); env:setStage(4)
end

local function experimentDevice(env)
  env:say("The prototype attractor\nhums at an unpleasant\nfrequency.")
  local observed=env:incidentFlag("observed")
  local rows={
    {label=observed and "FIX SWITCH" or "OBSERVE",value=observed and "sabotage" or "observe"},
    {label="LEAVE",value="leave"},
  }
  local choice=env:choose("ATTRACTOR",rows)
  if choice=="leave" or not choice then return end
  if choice=="observe" then
    env:say("A scratched frequency\nlabel doesn't match the\nswitch position.")
    env:setIncidentFlag("observed",true); env:setStage(4); return
  end

  env:meet("cass")
  env:setOperativeFlag("cass","sabotaged",true)
  env:say("You move the switch one\nnotch.\fThe machine SHRIEKS.\fCASS: WHAT DID YOU DO?\fSCIENTIST: TECHNICALLY?\nCORRECTED THE TUNING.")
  local result=env:wildBattle("RATTATA",18)
  if result=="loss" then
    env:finish("ROCKET_SUCCESS","Rocket recovered the attractor after the experiment broke loose.")
    return
  end
  env:say("CASS: WE'RE DONE HERE.\fSCIENTIST: SHOULD WE TAKE\nTHE ATTRACTOR?\fCASS: NOT IF YOU WANT\nTO CARRY IT.")
  if env:giveCargo(150) then env:finish("RESOLVED_ALTERNATE","The attractor was retuned and Rocket abandoned the experiment.") end
end

Incidents.ALL={
  intercepted_shipment={
    id="intercepted_shipment",title="INTERCEPTED SHIPMENT",operative="ronnie",expiry=2500,
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
      "SIGNAL: VERY STRONG\fRONNIE: I'M IN POSITION.\f???: GOOD. STAY OUT\nOF SIGHT.\fRONNIE: THERE'S A KID\nSTARING AT ME.\f???: THEN ACT NORMAL.\fRONNIE: HOW?",
    },
    actors={
      {role="ronnie",name="DS_ROCKET_RONNIE",sprite="SPRITE_ROCKET",text="TEXT_DS_ROCKET_SHIPMENT_RONNIE",dx=0,dy=0,phases={active=true}},
      {role="crate",name="DS_ROCKET_SHIPMENT_CRATE",sprite="SPRITE_POKE_BALL",text="TEXT_DS_ROCKET_SHIPMENT_CRATE",dx=1,dy=0,phases={active=true,reward=true}},
    },
    interact={ronnie=shipmentRonnie,crate=shipmentCrate},
  },

  hidden_cache={
    id="hidden_cache",title="HIDDEN CACHE",operative="milo",expiry=2800,
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
      "LOCAL FRAGMENT\fCHECK NEAR THE OLD\nFOREST MARKER.\fMILO: I'VE BEEN SENT TO\nHIDE SOMETHING THAT WAS\nALREADY HIDDEN.",
    },
    actors={
      {role="milo",name="DS_ROCKET_MILO",sprite="SPRITE_ROCKET",text="TEXT_DS_ROCKET_CACHE_MILO",dx=2,dy=0,phases={active=true}},
      {role="cache",name="DS_ROCKET_CACHE",sprite="SPRITE_POKE_BALL",text="TEXT_DS_ROCKET_CACHE_BOX",dx=0,dy=0,phases={active=true,reward=true}},
    },
    interact={milo=cacheMilo,cache=cacheBox},
  },

  illegal_experiment={
    id="illegal_experiment",title="ILLEGAL EXPERIMENT",operative="cass",expiry=3000,
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
