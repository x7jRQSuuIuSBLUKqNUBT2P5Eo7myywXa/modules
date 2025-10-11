local null, Not, filter; do
	local util = require(game:GetService('ServerStorage'):WaitForChild('src').BattleUtilities)
	null = util.null
	Not = util.Not
	filter = util.filter
end

--[[
	Todo:
	
	 Todo: Mimicry Screen Cleaner >252
	267 max todo
--]]

self = nil -- to hush intelisense; self property is injected at object-call simulation; see BattleEngine::call / BattleEngine::callAs

return {
	['battlebond'] = {
		onSourceFaint = function(target, source, effect)
			if effect and effect.effectType == 'Move' and source.template.species == 'Greninja' and source.template.forme == 'BB' and source.hp > 0 and not source.transformed and source.side.foe.pokemonLeft > 0 then
				self:add('-activate', source, 'ability: Battle Bond')
				local template = self:getTemplate('Greninja-Ash')
				source:formeChange(template)
				source.baseTemplate = template
				source.details = template.species .. ', L' .. source.level .. (source.gender == '' and '' or ', ') .. source.gender .. (source.set.shiny and ', shiny' or '')
				self:add('detailschange', source, source.details, '[battleBond]', '[icon] '..(template.icon or 0))
				local shinyPrefix = source.shiny and '_SHINY' or ''
				self:setupDataForTransferToPlayers('Sprite', shinyPrefix..'_FRONT/Greninja-ash')
				self:setupDataForTransferToPlayers('Sprite', shinyPrefix..'_BACK/Greninja-ash')

				source.iconOverride = template.icon-1
				-- is there a better way to access this?
				source.frontSpriteOverride = require(game:GetService('ServerStorage').Data.GifData)[shinyPrefix..'_FRONT']['Greninja-ash']
				source.baseStatOverride = template.baseStats
			end
		end,
		onModifyMove = function(move, attacker)
			if move.id == 'watershuriken' and attacker.template.species == 'Greninja' and attacker.template.forme == 'Ash' then
				--				self:debug('battle bond modify watershuriken')
				-- for some reason base power is handled on the move itself
				move.multihit = 3
			end
		end,
		id = "battlebond",
		name = "Battle Bond",
		rating = 3,
		num = 210,
	},
	['liquidvoice'] = {
		onModifyMovePriority = -1,
		onModifyMove = function(move)
			if move.flags and move.flags['sound'] then
				move.type = 'Water'
			end
		end,
		id = "liquidvoice",
		name = "Liquid Voice",
		rating = 2.5,
		num = 204,
	},
	['longreach'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if move.flags['contact'] then
				return self:chainModify(1.2)
			end
		end,
		onModifyMove = function(move)
			if move.flags then
				move.flags['contact'] = nil
			end
		end,
		id = "longreach",
		name = "Long Reach",
		rating = 3,
		num = 203,
	},
	['slushrush'] = {
		onModifySpe = function(spe, pokemon)
			if self:isWeather('hail') then
				return self:chainModify(2)
			end
		end,
		onImmunity = function(type, pokemon)
			if type == 'hail' then return false end
		end,
		id = "slushrush",
		name = "Slush Rush",
		rating = 2.5,
		num = 202,
	},

	['adaptability'] = {
		onModifyMove = function(move)
			move.stab = 2
		end,
		id = "adaptability",
		name = "Adaptability",
		rating = 3.5,
		num = 91
	},
	['aftermath'] = {
		id = "aftermath",
		name = "Aftermath",
		onAfterDamageOrder = 1,
		onAfterDamage = function(damage, target, source, move)
			if source and source ~= target and move and move.flags['contact'] and target.hp <= 0 then
				self:damage(source.maxhp / 4, source, target, nil, true)
			end
		end,
		rating = 2.5,
		num = 106
	},
	['aerilate'] = {
		onModifyMovePriority = -1,
		onModifyMove = function(move, pokemon)
			if move.type == 'Normal' and move.id ~= 'naturalgift' then
				move.type = 'Flying'
				if move.category ~= 'Status' then
					pokemon:addVolatile('aerilate')
				end
			end
		end,
		effect = {
			duration = 1,
			onBasePowerPriority = 8,
			onBasePower = function(basePower, pokemon, target, move)
				return self:chainModify(0x1333, 0x1000)
			end
		},
		id = "aerilate",
		name = "Aerilate",
		rating = 4,
		num = 185
	},
	['airlock'] = {
		onStart = function(pokemon)
			self:add('-ability', pokemon, 'Air Lock')
		end,
		suppressWeather = true,
		id = "airlock",
		name = "Air Lock",
		rating = 3,
		num = 76
	},
	['analytic'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if not self:willMove(defender) then
				self:debug('Analytic boost')
				return self:chainModify(0x14CD, 0x1000)
			end
		end,
		id = "analytic",
		name = "Analytic",
		rating = 2,
		num = 148
	},
	['angerpoint'] = {
		onAfterDamage = function(damage, target, source, move)
			if target.hp <= 0 then return end
			if move and move.effectType == 'Move' and move.crit then
				target:setBoost({atk = 6})
				self:add('-setboost', target, 'atk', 12, '[from] ability: Anger Point')
			end
		end,
		id = "angerpoint",
		name = "Anger Point",
		rating = 2,
		num = 83
	},
	['anticipation'] = {
		onStart = function(pokemon)
			pokemon.anticipationActivated = false
			for _, target in pairs(pokemon.side.foe.active) do
				if target ~= null and not target.fainted then
					for _, m in pairs(target.moveset) do
						local move = self:getMove(m.move)
						if move.category ~= 'Status' and (self:getImmunity(move.type, pokemon) and self:getEffectiveness(move.type, pokemon) > 1 or move.ohko) then
							self:add('-ability', pokemon, 'Anticipation')
							pokemon.anticipationActivated = true
							return
						end
					end
				end
			end
		end,
		onSourceModifyDamage = function(damage, source, target, move)
			if target.anticipationActivated and target.activeTurns < 1 then
				self:debug('Anticipation weaken')
				return self:chainModify(0.5)
			end
		end,
		id = "anticipation",
		name = "Anticipation",
		rating = 1,
		num = 107
	},
	['arenatrap'] = {
		onFoeModifyPokemon = function(pokemon)
			if not self:isAdjacent(pokemon, self.effectData.target) then return end
			if pokemon:isGrounded() then
				pokemon:tryTrap(true, self.effectData.target, 'Arena Trap')
			end
		end,
		onFoeMaybeTrapPokemon = function(pokemon, source)
			if not source then source = self.effectData.target end
			if not self:isAdjacent(pokemon, source) then return end
			if pokemon:isGrounded() then
				pokemon.maybeTrapped = true
			end
		end,
		id = "arenatrap",
		name = "Arena Trap",
		rating = 4.5,
		num = 71
	},
	['aromaveil'] = {
		onAllyTryHit = function(target, source, move)
			local protects = {'attract', 'disable', 'encore', 'healblock', 'taunt', 'torment'}
			if move and protects[move.id] then
				return false
			end
		end,
		id = "aromaveil",
		name = "Aroma Veil",
		rating = 1.5,
		num = 165
	},
	['aurabreak'] = {
		onStart = function(pokemon)
			self:add('-ability', pokemon, 'Aura Break')
		end,
		onAnyTryPrimaryHit = function(target, source, move)
			if target == source or move.category == 'Status' then return end
			source:addVolatile('aurabreak')
		end,
		effect = {
			duration = 1
		},
		id = "aurabreak",
		name = "Aura Break",
		rating = 2,
		num = 188
	},
	['baddreams'] = {
		onResidualOrder = 26,
		onResidualSubOrder = 1,
		onResidual = function(pokemon)
			if pokemon.hp <= 0 then return end
			for _, target in pairs(pokemon.side.foe.active) do
				if target ~= null and target.hp > 0 then
					if target.status == 'slp' then
						self:damage(target.maxhp / 8, target)
					end
				end
			end
		end,
		id = "baddreams",
		name = "Bad Dreams",
		rating = 2,
		num = 123
	},
	['battlearmor'] = {
		onCriticalHit = function() return false end,
		id = "battlearmor",
		name = "Battle Armor",
		rating = 1,
		num = 4
	},
	['bigpecks'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, attacker, defender, move)
			if move.type == 'Flying' then
				self:debug('Big Pecks boost')
				return self:chainModify(1.3)
			end
		end,
		onModifySpAPriority = 5,
		onModifySpA = function(atk, attacker, defender, move)
			if move.type == 'Flying' then
				self:debug('Big Pecks boost')
				return self:chainModify(1.3)
			end
		end,
		id = "bigpecks",
		name = "Big Pecks",
		rating = 2,
		num = 145
	},
	['blaze'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, attacker, defender, move)
			if move.type == 'Fire' then
				self:debug('Blaze boost')
				return self:chainModify(1.3)
			end
		end,
		onModifySpAPriority = 5,
		onModifySpA = function(atk, attacker, defender, move)
			if move.type == 'Fire' then
				self:debug('Blaze boost')
				return self:chainModify(1.3)
			end
		end,
		id = "blaze",
		name = "Blaze",
		rating = 2,
		num = 66
	},
	['supersweetsyrup'] = {
		onModifyAccuracy = function(target, accuracy)
			if type(accuracy) ~= 'number' then return end
			self:debug('Supersweet Syrup - decreasing accuracy')
			return accuracy * 0.5
		end,
		id = "supersweetsyrup",
		name = "Supersweet Syrup",
		rating = 1.5,
		num = 332
	},
	['bulletproof'] = {
		onTryHit = function(pokemon, target, move)
			if move.flags['bullet'] then
				self:add('-immune', pokemon, '[msg]', '[from] Bulletproof')
				return null
			end
		end,
		id = "bulletproof",
		name = "Bulletproof",
		rating = 3,
		num = 171
	},
	['cheekpouch'] = {
		onEatItem = function(item, pokemon)
			self:heal(pokemon.maxhp / 3)
		end,
		id = "cheekpouch",
		name = "Cheek Pouch",
		rating = 2,
		num = 167
	},
	['chlorophyll'] = {
		onModifySpe = function(spe)
			if self:isWeather({'sunnyday', 'desolateland'}) then
				return self:chainModify(2)
			end
		end,
		id = "chlorophyll",
		name = "Chlorophyll",
		rating = 2.5,
		num = 34
	},
	['clearbody'] = {
		onBoost = function(boost, target, source, effect)
			if source and target == source then return end
			local showMsg = false
			for i, b in pairs(boost) do
				if b < 0 then
					boost[i] = nil
					showMsg = true
				end
			end
			if showMsg and not effect.secondaries then
				self:add("-fail", target, "unboost", "[from] ability = Clear Body", "[of] " .. target)
			end
		end,
		id = "clearbody",
		name = "Clear Body",
		rating = 2,
		num = 29
	},
	['cloudnine'] = {
		onStart = function(pokemon)
			self:add('-ability', pokemon, 'Cloud Nine')
		end,
		suppressWeather = true,
		id = "cloudnine",
		name = "Cloud Nine",
		rating = 3,
		num = 13
	},
	['colorchange'] = {
		onAfterMoveSecondary = function(target, source, move)
			local type = move.type
			if target.isActive and move.effectType == 'Move' and move.category ~= 'Status' and type ~= '???' and not target:hasType(type) then
				if not target:setType(type) then return false end
				self:add('-start', target, 'typechange', type, '[from] Color Change')
				target:update()
			end
		end,
		id = "colorchange",
		name = "Color Change",
		rating = 1,
		num = 16
	},
	['innardsout'] = {
		name = "Innards Out",
		onDamagingHitOrder = 1,
		onDamagingHit = function(damage, target, source, move)
			if not (target.hp) then
				self:damage(target.getUndynamaxedHP(damage), source, target)
			end
		end,
		rating = 4,
		num = 215,
		id = 'innardsout'
	},
	['dancer'] = {
		name = "Dancer",
		id = 'dancer',
		--implemented in runMove in scripts.js
		rating = 1.5,
		num = 216,
	},
	['steelworker'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, attacker, defender, move)
			if (move.type == 'Steel') then
				return self:chainModify(1.5)
			end
		end,
		onModifySpAPriority = 5,
		onModifySpA = function(atk, attacker, defender, move)
			if (move.type == 'Steel') then
				return self:chainModify(1.5)
			end
		end,
		name = "Steelworker",
		rating = 3.5,
		num = 200,
		id = 'steelworker'
	},
	['prismarmor'] = {
		onSourceModifyDamage = function(damage, source, target, move)
			if (move.target.typeMod > 0) then
				return self:chainModify(0.75)
			end
		end,
		isUnbreakable = true,
		name = "Prism Armor",
		rating = 3,
		num = 232,
		id = 'prismarmor'
	},
	['neuroforce'] = {
		onModifyDamage = function(damage, source, target, move)
			if (move and target:getMoveHitData(move).typeMod > 0) then
				return self:chainModify(0.75) --[5120, 4096]
			end
		end,
		name = "Neuroforce",
		rating = 2.5,
		num = 233,
		id = 'neuroforce'
	},
	['intrepidsword'] = {
		onStart = function(pokemon)
			self:boost({atk = 1})
		end,
		id = "intrepidsword",
		name = "Intrepid Sword",
		rating = 2.5,
		num = 234
	},
	['dauntlessshield'] = {
		onStart = function(pokemon)
			self:boost({def = 1})
		end,
		id = "dauntlessshield",
		name = "Dauntless Shield",
		rating = 2.5,
		num = 235
	},
	['ballfetch'] = {
		name = "Ball Fetch",
		rating = 0,
		num = 237,
		id = 'ballfetch'
	},
	['cottondown'] = {
		onDamagingHit = function(damage, target, source, move)
			local activated = false
			for _, pokemon in pairs(self:getAllActive()) do
				if not (pokemon == target or pokemon.fainted) then return end
				if not (activated) then
					self:add('-ability', target, 'Cotton Down')
					activated = true
				end
				self:boost({spe = -1}, pokemon, target, nil, true)
			end
		end,
		name = "Cotton Down",
		rating = 2,
		num = 238,
		id = 'cottondown'
	},
	['propellertail'] = {   
		onRedirectTargetPriority = 3,
		onRedirectTarget = function(target, source, move) 
			-- Fires for all pokemon on the ability holder's side apparently
			-- Ensure source is the ability holder
			self:debug('onRedirectTarget: ${target} (${target.side.name}), ${source} (${source.side.name}), ${source2}, ${move}')
			local te = self:getAbility(target.ability)
			if (te == 'propellertail')then
				self:debug('Propeller Tail prevented redirection')
				return target
			end
		end,
		id = "propellertail",
		name = "Propeller Tail",
		rating = 0,
		num = 239
	},
	['dazzling'] = {
		onFoeTryMove = function(target, source, move)
			local targetAllExceptions = {'perishsong', 'flowershield', 'rototiller'}
			if (move.target == 'foeSide' or (move.target == 'all' and not targetAllExceptions:find(move.id))) then
				return
			end
			local dazzlingHolder = self.effectData.target
			if ((source.side == dazzlingHolder.side or move.target == 'all') and move.priority > 0.1) then
				self:attrLastMove('[still]')
				self:add('cant', dazzlingHolder, 'ability: Dazzling', move, '[of] '..target)
				return false
			end
		end,
		name = "Dazzling",
		rating = 2.5,
		num = 219,
		id = 'dazzling'
	},
	['soulheart'] = {
		onAnyFaintPriority = 1,
		onAnyFaint = function()
			self:boost({spa = 1}, self.effectData.target)
		end,
		name = "Soul-Heart",
		rating = 3.5,
		num = 220,
		id = 'soulheart'
	},
	['receiver'] = {
		onAllyFaint = function(target)
			if not (self.effectData.target.hp) then return end
			local ability = target:getAbility()
			local additionalBannedAbilities = {'noability', 'flowergift', 'forecast', 'hungerswitch', 'illusion', 'imposter', 'neutralizinggas', 'powerofalchemy', 'receiver', 'trace', 'wonderguard'}
			if (additionalBannedAbilities:find(target.ability)) then return end
			self:add('-ability', self.effectData.target, ability, '[from] ability: Receiver', '[of] '..target)
			self.effectData.target:setAbility(ability)
		end,
		name = "Receiver",
		rating = 0,
		num = 222,
		id = 'receiver'
	},
	powerofalchemy = {
		onAllyFaint = function(target)
			if not (self.effectData.target.hp) then return end
			local ability = target:getAbility()
			local additionalBannedAbilities = {'noability', 'flowergift', 'forecast', 'hungerswitch', 'illusion', 'imposter', 'neutralizinggas', 'powerofalchemy', 'receiver', 'trace', 'wonderguard'}
			if (additionalBannedAbilities:find(target.ability)) then return end
			self:add('-ability', self.effectData.target, ability, '[from] ability: Power of Alchemy', '[of] '..target)
			self.effectData.target:setAbility(ability)
		end,
		name = "Power of Alchemy",
		rating = 0,
		num = 223,
		id = 'powerofalchemy'
	},
	['beastboost'] = {
		onSourceFaint = function(target, source, effect)
			if effect and effect.effectType == 'Move' then 
				local stat = 'atk'
				local bestStat = 0
				for i, s in pairs(source.stats) do
					if (source.stats[i] > bestStat) then
						stat = i
						bestStat = source.stats[i]
					end
				end
				self:boost({[stat]=1}, source)
			end
		end,
		id = "beastboost",
		name = "Beast Boost",
		rating = 3.5,
		num = 224,
	},
	rkssystem = {
		-- RKS System's type-changing itself is implemented in statuses.js
		name = "RKS System",
		rating = 4,
		num = 225,
		id = 'rkssystem'
	},
	tanglinghair = {
		onDamagingHit = function(damage, target, source, move)
			if (move.flags['contact']) then
				self:add('-ability', target, 'Tangling Hair')
				self:boost({spe = -1}, source, target, nil, true)
			end
		end,
		name = "Tangling Hair",
		rating = 2,
		num = 221,
		id = 'tanglinghair'
	},
	['comatose'] = {
		onResidualOrder = 5,
		onResidualSubOrder = 1,
		onResidual = function(pokemon)
			self:debug('Simple Comatose')
			pokemon:cureStatus()
		end,
		id ="comatose",
		name = "Comatose",
		rating = 3,
		num = 213,
	},
	['competitive'] = {
		onAfterEachBoost = function(boost, target, source)
			if not source or target.side == source.side then return end
			local statsLowered = false
			for i, b in pairs(boost) do
				if b < 0 then
					statsLowered = true
					break
				end
			end
			if statsLowered then
				self:boost({spa = 2})
			end
		end,
		id = "competitive",
		name = "Competitive",
		rating = 2.5,
		num = 172
	},
	['compoundeyes'] = {
		onSourceModifyAccuracy = function(accuracy)
			if type(accuracy) ~= 'number' then return end
			self:debug('compoundeyes - enhancing accuracy')
			return accuracy * 1.3
		end,
		id = "compoundeyes",
		name = "Compound Eyes",
		rating = 3.5,
		num = 14
	},
	['contrary'] = {
		onBoost = function(boost)
			for i, b in pairs(boost) do
				boost[i] = -b
			end
		end,
		id = "contrary",
		name = "Contrary",
		rating = 4,
		num = 126
	},
	['cursedbody'] = {
		onAfterDamage = function(damage, target, source, move)
			if not source or source.volatiles['disable'] then return end
			if source ~= target and move and move.effectType == 'Move' then
				if math.random(10) <= 3 then
					source:addVolatile('disable')
				end
			end
		end,
		id = "cursedbody",
		name = "Cursed Body",
		rating = 2,
		num = 130
	},
	['cutecharm'] = {
		onAfterDamage = function(damage, target, source, move)
			if move and move.flags['contact'] then
				if math.random(10) <= 3 then
					source:addVolatile('attract', target)
				end
			end
		end,
		id = "cutecharm",
		name = "Cute Charm",
		rating = 1,
		num = 56
	},
	['damp'] = {
		id = "damp",
		onAnyTryMove = function(target, source, effect)
			if effect.id == 'selfdestruct' or effect.id == 'explosion' then
				self:attrLastMove('[still]')
				self:add('-activate', self.effectData.target, 'ability = Damp')
				return false
			end
		end,
		onAnyDamage = function(damage, target, source, effect)
			if effect and effect.id == 'aftermath' then
				return false
			end
		end,
		name = "Damp",
		rating = 1,
		num = 6
	},
	['darkaura'] = {
		onStart = function(pokemon)
			self:add('-ability', pokemon, 'Dark Aura')
		end,
		onAnyTryPrimaryHit = function(target, source, move)
			if target == source or move.category == 'Status' then return end
			if move.type == 'Dark' then
				source:addVolatile('aura')
			end
		end,
		id = "darkaura",
		name = "Dark Aura",
		rating = 3,
		num = 186
	},
	['adrenaline'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, pokemon)
			if pokemon.hp <= pokemon.maxhp/2 then
				return self:chainModify(1.5)
			end
		end,
		onModifySpAPriority = 5,
		onModifySpA = function(atk, pokemon)
			if pokemon.hp <= pokemon.maxhp/2 then
				return self:chainModify(1.5)
			end
		end,
		onResidual = function(pokemon)
			pokemon:update()
		end,
		id = "adrenaline",
		name = "Adrenaline",
		rating = 4,
		num = 129
	},
	['defiant'] = {
		onAfterEachBoost = function(boost, target, source)
			if not source or target.side == source.side then return end
			local statsLowered = false
			for i, b in pairs(boost) do
				if b < 0 then
					statsLowered = true
					break
				end
			end
			if statsLowered then
				self:boost({atk = 2})
			end
		end,
		id = "defiant",
		name = "Defiant",
		rating = 2.5,
		num = 128
	},
	['deltastream'] = {
		onStart = function(source)
			self:setWeather('deltastream')
		end,
		onAnySetWeather = function(target, source, weather)
			local allowedWeathers = {primordialsea = true, desolateland = true, none = true}
			if self:getWeather().id == 'desolateland' and not allowedWeathers[weather.id] then
				return false
			end
		end,
		onEnd = function(pokemon)
			if self.weatherData.source ~= pokemon then
				return
			end
			local hasDeltaStreamAbility = false
			for _, side in pairs(self.sides) do
				for _, target in pairs(side.active) do
					if target and target ~= pokemon and target.hp > 0 and target:getAbility().id == 'deltastream' then
						self.weatherData.source = target
						hasDeltaStreamAbility = true
						break
					end
				end
				if hasDeltaStreamAbility then
					break
				end
			end
			if not hasDeltaStreamAbility then
				self.weatherData.duration = 0 -- Reset the weather duration to 0
				self.weather = nil -- Clear the weather
			end
		end,
		id = "deltastream",
		name = "Delta Stream",
		rating = 5,
		num = 191
	},
	['desolateland'] = {
		onStart = function(source)
			self:setWeather('desolateland')
		end,
		onAnySetWeather = function(target, source, weather)
			local allowedWeathers = {primordialsea = true, deltastream = true, none = true}
			if self:getWeather().id == 'desolateland' and not allowedWeathers[weather.id] then
				return false
			end
		end,
		onEnd = function(pokemon)
			if self.weatherData.source ~= pokemon then
				return
			end
			local hasDesolateLandAbility = false
			for _, side in pairs(self.sides) do
				for _, target in pairs(side.active) do
					if target and target ~= pokemon and target.hp > 0 and target:getAbility().id == 'desolateland' then
						self.weatherData.source = target
						hasDesolateLandAbility = true
						break
					end
				end
				if hasDesolateLandAbility then
					break
				end
			end
			if not hasDesolateLandAbility then
				self.weatherData.duration = 0 -- Reset the weather duration to 0
				self.weather = nil -- Clear the weather
			end
		end,
		id = "desolateland",
		name = "Desolate Land",
		rating = 5,
		num = 190
	},
	['download'] = {
		onStart = function(pokemon)
			local totaldef = 0
			local totalspd = 0
			for _, foe in pairs(pokemon.side.foe.active) do
				if foe ~= null and not foe.fainted then
					totaldef = totaldef + foe:getStat('def', false, true)
					totalspd = totalspd + foe:getStat('spd', false, true)
				end
			end
			if totaldef and totaldef >= totalspd then
				self:boost({spa = 1})
			elseif totalspd > 0 then
				self:boost({atk = 1})
			end
		end,
		id = "download",
		name = "Download",
		rating = 4,
		num = 88
	},
	['drizzle'] = {
		onStart = function(source)
			self:setWeather('raindance', source)
		end,
		id = "drizzle",
		name = "Drizzle",
		rating = 4,
		num = 2
	},
	['drought'] = {
		onStart = function(source)
			self:setWeather('sunnyday', source)
		end,
		id = "drought",
		name = "Drought",
		rating = 4,
		num = 70
	},


	['dryskin'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Water' then
				local h = self:heal(target.maxhp / 4)
				if not h or h == 0 then
					self:add('-immune', target, '[msg]')
				end
				return null
			end
		end,
		onBasePowerPriority = 7,
		onFoeBasePower = function(basePower, attacker, defender, move)
			if self.effectData.target ~= defender then return end
			if move.type == 'Fire' then
				return self:chainModify(1.25)
			end
		end,
		onWeather = function(target, source, effect)
			if effect.id == 'raindance' or effect.id == 'primordialsea' then
				self:heal(target.maxhp / 8)
			elseif effect.id == 'sunnyday' or effect.id == 'desolateland' then
				self:damage(target.maxhp / 8)
			end
		end,
		id = "dryskin",
		name = "Dry Skin",
		rating = 3.5,
		num = 87
	},
	['earlybird'] = {
		id = "earlybird",
		name = "Early Bird",
		-- Implemented in Statuses
		rating = 2.5,
		num = 48
	},
	['effectspore'] = {
		onAfterDamage = function(damage, target, source, move)
			if move and move.flags['contact'] and (not source.status or source.status == '') and source:runImmunity('powder') then
				local r = math.random(100)
				if r <= 30 then
					self.statusSourceMessage = {'-ability', target, 'effectspore'}
				end
				if r <= 10 then
					source:setStatus('slp', target)
				elseif r <= 20 then
					source:setStatus('par', target)
				elseif r <= 30 then
					source:setStatus('psn', target)
				end
				self.statusSourceMessage = nil
			end
		end,
		id = "effectspore",
		name = "Effect Spore",
		rating = 2,
		num = 27
	},
	['fairyaura'] = {
		onStart = function(pokemon)
			self:add('-ability', pokemon, 'Fairy Aura')
		end,
		onAnyTryPrimaryHit = function(target, source, move)
			if target == source or move.category == 'Status' then return end
			if move.type == 'Fairy' then
				source:addVolatile('aura')
			end
		end,
		id = "fairyaura",
		name = "Fairy Aura",
		rating = 3,
		num = 187
	},
	['filter'] = {
		onSourceModifyDamage = function(damage, source, target, move)
			if move.typeMod > 0 then --if self:getEffectiveness(move, target) > 1 then
				self:debug('Filter neutralize')
				return self:chainModify(0.75)
			end
		end,
		id = "filter",
		name = "Filter",
		rating = 3,
		num = 111
	},
	['flamebody'] = {
		onAfterDamage = function(damage, target, source, move)
			if move and move.flags['contact'] then
				if math.random(10) <= 3 then
					self.statusSourceMessage = {'-ability', target, 'flamebody'}
					source:trySetStatus('brn', target, move)
					self.statusSourceMessage = nil
				end
			end
		end,
		id = "flamebody",
		name = "Flame Body",
		rating = 2,
		num = 49
	},
	['flareboost'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if attacker.status == 'brn' then
				return self:chainModify(1.5)
			end
		end,
		id = "flareboost",
		name = "Flare Boost",
		rating = 2.5,
		num = 138
	},
	['flashfire'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Fire' then
				move.accuracy = true
				if not target:addVolatile('flashfire') then
					self:add('-immune', target, '[msg]')
				end
				return null
			end
		end,
		onEnd = function(pokemon)
			pokemon:removeVolatile('flashfire')
		end,
		effect = {
			noCopy = true, -- doesn't get copied by Baton Pass
			onStart = function(target)
				self:add('-start', target, 'ability = Flash Fire')
			end,
			onModifyAtkPriority = 5,
			onModifyAtk = function(atk, attacker, defender, move)
				if move.type == 'Fire' then
					self:debug('Flash Fire boost')
					return self:chainModify(1.5)
				end
			end,
			onModifySpAPriority = 5,
			onModifySpA = function(atk, attacker, defender, move)
				if move.type == 'Fire' then
					self:debug('Flash Fire boost')
					return self:chainModify(1.5)
				end
			end,
			onEnd = function(target)
				self:add('-end', target, 'ability: Flash Fire', '[silent]')
			end
		},
		id = "flashfire",
		name = "Flash Fire",
		rating = 3,
		num = 18
	},
	['flowergift'] = {
		onStart = function(pokemon)
			self.effectData.forme = nil
		end,
		onUpdate = function(pokemon)
			if not pokemon.isActive or pokemon.baseTemplate.speciesid ~= 'cherrim' then return end
			if self:isWeather({'sunnyday', 'desolateland'}) then
				if pokemon.template.speciesid ~= 'cherrimsunshine' then
					pokemon:formeChange('Cherrim-Sunshine')
					self:add('-formechange', pokemon, 'Cherrim-Sunshine', '[msg]')
				end
			else
				if pokemon.template.speciesid == 'cherrimsunshine' then
					pokemon:formeChange('Cherrim')
					self:add('-formechange', pokemon, 'Cherrim', '[msg]')
				end
			end
		end,
		onModifyAtkPriority = 3,
		onAllyModifyAtk = function(atk)
			if self.effectData.target.baseTemplate.speciesid ~= 'cherrim' then return end
			if self:isWeather({'sunnyday', 'desolateland'}) then
				return self:chainModify(1.5)
			end
		end,
		onModifySpDPriority = 4,
		onAllyModifySpD = function(spd)
			if self.effectData.target.baseTemplate.speciesid ~= 'cherrim' then return end
			if self:isWeather({'sunnyday', 'desolateland'}) then
				return self:chainModify(1.5)
			end
		end,
		id = "flowergift",
		name = "Flower Gift",
		rating = 2.5,
		num = 122
	},
	['flowerveil'] = {
		onAllyBoost = function(boost, target, source, effect)
			if (source and target == source) then return end
			local showMsg = false
			for i, b in pairs(boost) do
				if b < 0 then
					boost[i] = nil
					showMsg = true
				end
			end
			if showMsg and not effect.secondaries then
				self:add("-fail", target, "unboost", "[from] ability = Flower Veil", "[of] " .. target)
			end
		end,
		onAllySetStatus = function(status, target)
			return false
		end,
		id = "flowerveil",
		name = "Flower Veil",
		rating = 0,
		num = 166
	},
	['forecast'] = {
		onUpdate = function(pokemon)
			if pokemon.baseTemplate.species ~= 'Castform' or pokemon.transformed then return end
			local forme
			local w = self:effectiveWeather()
			if (w == 'sunnyday' or w == 'desolateland') and pokemon.template.speciesid ~= 'castformsunny' then
				forme = 'Castform-Sunny'
			elseif (w == 'raindance' or w == 'primordialsea') and pokemon.template.speciesid ~= 'castformrainy' then
				forme = 'Castform-Rainy'
			elseif w == 'hail' and pokemon.template.speciesid ~= 'castformsnowy' then
				forme = 'Castform-Snowy'
			elseif pokemon.template.speciesid ~= 'castform' then
				forme = 'Castform'
			end
			if pokemon.isActive and forme then
				pokemon:formeChange(forme)
				self:add('-formechange', pokemon, forme, '[msg]')
			end
		end,
		id = "forecast",
		name = "Forecast",
		rating = 3,
		num = 59
	},
	['mirrorarmor'] = {
		onBoost = function(boost, target, source, effect)
			--Don't bounce self stat changes, or boosts that have already bounced
			if (target == source and not boost and effect.id == 'mirrorarmor') then return end
			for _, b in pairs(boost) do
				if (boost[b] < 0) then
					if (target.boosts[b] == -6) then return end
					local negativeBoost = {}
					negativeBoost[b] = boost[b]
					boost[b] = nil
					self:add('-ability', target, 'Mirror Armor')
					self:boost(negativeBoost, source, target, null, true)
				end
			end
		end,
		name = "Mirror Armor",
		id = 'mirrorarmor',
		rating = 2,
		num = 240,
	},
	['gulpmissile'] = {
		onBeforeMovePriority = 11,
		onBeforeMove = function(pokemon, target, move)
			if pokemon.template.species ~= 'Cramorant' then return end
			if pokemon.hp < pokemon.maxhp/2 then
				if Not(pokemon.template.forme) and pokemon:formeChange('Cramorant-Gorging') then
					self:add('-formechange', pokemon, 'Cramorant-Gorging')
				end
			else
				if Not(pokemon.template.forme) and pokemon:formeChange('Cramorant-Gulping') then
					self:add('-formechange', pokemon, 'Cramorant-Gulping')
				end
			end
		end,
		onAfterDamageOrder = 1,
		onAfterDamage = function(damage, target, source, move)
			if source and source ~= target and move and move.flags['contact'] then
				if target.template.forme == 'Gorging' and target:formeChange('Cramorant') then
					self:add('-formechange', target, 'Cramorant')
					source:setStatus('par', source)
					self:damage(source.maxhp / 4, source, target, nil, true)
				elseif target.template.forme == 'Gulping' and target:formeChange('Cramorant') then
					self:add('-formechange', target, 'Cramorant')
					self:boost({def = -1}, source, target)
					self:damage(source.maxhp / 4, source, target, nil, true)
				end
			end
		end,
		id = "gulpmissile",
		name = "Gulp Missile",
		rating = -1,
		num = 241
	},
	['stalwart'] = {
		onModifyMove =  function(move)
			--this doesn't actually do anything because ModifyMove happens after the tracksTarget check
			--the actual implementation is in Battle#getTarget
			move.tracksTarget = true
		end,
		name = "Stalwart",
		rating = 0,
		num = 242,
		id = 'stalwart'
	},
	['forewarn'] = {
		onStart = function(pokemon)
			local warnMoves = {}
			local warnBp = 1
			for _, target in pairs(pokemon.side.foe.active) do
				if target ~= null and not target.fainted then
					for _, m in pairs(target.moveset) do
						local move = self:getMove(m.move)
						local bp = move.basePower
						if move.ohko then bp = 160 end
						if move.id == 'counter' or move.id == 'metalburst' or move.id == 'mirrorcoat' then bp = 120 end
						if (not bp or bp == 0) and move.category ~= 'Status' then bp = 80 end
						if bp > warnBp then
							warnMoves = {{move, target}}
							warnBp = bp
						elseif bp == warnBp then
							table.insert(warnMoves, {move, target})
						end
					end
				end
			end
			if #warnMoves == 0 then return end
			local warnMove = warnMoves[math.random(#warnMoves)]
			self:add('-activate', pokemon, 'ability = Forewarn', warnMove[1], '[of] ' .. warnMove[2])
		end,
		id = "forewarn",
		name = "Forewarn",
		rating = 1,
		num = 108
	},
	['friendguard'] = {
		id = "friendguard",
		name = "Friend Guard",
		onAnyModifyDamage = function(damage, source, target, move)
			if target ~= self.effectData.target and target.side == self.effectData.target.side then
				self:debug('Friend Guard weaken')
				return self:chainModify(0.75)
			end
		end,
		onAllySetStatus = function(status, target)
			return false
		end,
		rating = 0,
		num = 132
	},
	['frisk'] = {
		onStart = function(pokemon)
			for _, foe in pairs(pokemon.side.foe.active) do
				if foe ~= null and not foe.fainted then
					if foe.item and foe.item ~= '' then
						self:add('-item', foe, foe:getItem().name, '[from] ability = Frisk', '[of] ' .. pokemon, '[identify]')
					end
				end
			end
		end,
		id = "frisk",
		name = "Frisk",
		rating = 1.5,
		num = 119
	},
	['furcoat'] = {
		onModifyDefPriority = 6,
		onModifyDef = function(def)
			return self:chainModify(2)
		end,
		id = "furcoat",
		name = "Fur Coat",
		rating = 3.5,
		num = 169
	},
	['galewings'] = {
		onModifyPriority = function(priority, pokemon, target, move)
			if move and move.type == 'Flying' and pokemon.hp >= pokemon.maxhp/2 then return priority + 1 end
		end,
		id = "galewings",
		name = "Gale Wings",
		rating = 3,
		num = 177
	},
	['gluttony'] = {
		onEatItem = function(item, pokemon)
			self:heal(pokemon.maxhp / 3)
		end,
		id = "gluttony",
		name = "Gluttony",
		rating = 2,
		num = 82
	},
	['gooey'] = {
		onAfterDamage = function(damage, target, source, effect)
			if effect and effect.flags['contact'] then
				self:boost({spe = -1}, source, target)
			end
		end,
		id = "gooey",
		name = "Gooey",
		rating = 2.5,
		num = 183
	},
	['grasspelt'] = {
		onModifyDefPriority = 6,
		onModifyDef = function(pokemon) -- shouldn't it be def, pokemon? doesn't *really* matter cuz neither is used
			if self:isTerrain('grassyterrain') then
				return self:chainModify(1.5)
			end
		end,
		id = "grasspelt",
		name = "Grass Pelt",
		rating = 0.5,
		num = 179
	},
	['guts'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, pokemon)
			if pokemon.status and pokemon.status ~= '' then
				return self:chainModify(1.5)
			end
		end,
		id = "guts",
		name = "Guts",
		rating = 3,
		num = 62
	},
	['harvest'] = {
		id = "harvest",
		name = "Harvest",
		onResidualOrder = 26,
		onResidualSubOrder = 1,
		onResidual = function(pokemon)
			if self:isWeather({'sunnyday', 'desolateland'}) or math.random(2) == 1 then
				if pokemon.hp and Not(pokemon.item) and self:getItem(pokemon.lastItem).isBerry then
					pokemon:setItem(pokemon.lastItem)
					self:add('-item', pokemon, pokemon:getItem(), '[from] ability = Harvest')
				end
			end
		end,
		rating = 2.5,
		num = 139
	},
	['healer'] = {
		id = "healer",
		name = "Healer",
		onResidualOrder = 5,
		onResidualSubOrder = 1,
		onResidual = function(pokemon)
			if #pokemon.side.active == 1 then return end
			for _, ally in pairs(pokemon.side.active) do
				if ally ~= null and self:isAdjacent(pokemon, ally) and ally.status and math.random(10) <= 3 then
					ally:cureStatus()
				end
			end
		end,
		rating = 0,
		num = 131
	},
	['heatproof'] = {
		onBasePowerPriority = 7,
		onSourceBasePower = function(basePower, attacker, defender, move)
			if move.type == 'Fire' then
				return self:chainModify(0.5)
			end
		end,
		onDamage = function(damage, target, source, effect)
			if effect and effect.id == 'brn' then
				return damage / 2
			end
		end,
		id = "heatproof",
		name = "Heatproof",
		rating = 2.5,
		num = 85
	},
	['heavymetal'] = {
		onModifyWeight = function(weight)
			return weight * 2
		end,
		id = "heavymetal",
		name = "Heavy Metal",
		rating = -1,
		num = 134
	},
	['honeygather'] = {
		id = "honeygather",
		name = "Honey Gather",
		rating = 0,
		num = 118
	},
	['hugepower'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk)
			return self:chainModify(2)
		end,
		id = "hugepower",
		name = "Huge Power",
		rating = 5,
		num = 37
	},
	['hustle'] = {
		-- This should be applied directly to the stat as opposed to chaining witht he others
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk)
			return self:modify(atk, 1.5)
		end,
		onModifyMove = function(move)
			if move.category == 'Physical' and type(move.accuracy) == 'number' then
				move.accuracy = move.accuracy * 0.8
			end
		end,
		id = "hustle",
		name = "Hustle",
		rating = 3,
		num = 55
	},
	['hydration'] = {
		onResidualOrder = 5,
		onResidualSubOrder = 1,
		onResidual = function(pokemon)
			if pokemon.status and self:isWeather({'raindance', 'primordialsea'}) then
				self:debug('hydration')
				pokemon:cureStatus()
			end
		end,
		id = "hydration",
		name = "Hydration",
		rating = 2,
		num = 93
	},
	['hypercutter'] = {
		onBoost = function(boost, target, source, effect)
			if source and target == source then return end
			if boost['atk'] and boost['atk'] < 0 then
				boost['atk'] = 0
				if not effect.secondaries then
					self:add("-fail", target, "unboost", "Attack", "[from] ability = Hyper Cutter", "[of] " .. target)
				end
			end
		end,
		id = "hypercutter",
		name = "Hyper Cutter",
		rating = 1.5,
		num = 52
	},
	['icebody'] = {
		onWeather = function(target, source, effect)
			if effect.id == 'hail' then
				self:heal(target.maxhp / 16)
			end
		end,
		onImmunity = function(type, pokemon)
			if type == 'hail' then return false end
		end,
		id = "icebody",
		name = "Ice Body",
		rating = 1.5,
		num = 115
	},
	['illuminate'] = {
		id = "illuminate",
		name = "Illuminate",
		rating = 0,
		num = 35
	},
	['illusion'] = {
		onBeforeSwitchIn = function(pokemon)
			--if pokemon.template.forme ~= '' then return end
			pokemon.illusion = nil
			local illusion
			for i = #pokemon.side.pokemon, pokemon.position, -1 do
				local p = pokemon.side.pokemon[i]
				for i in ipairs(p) do
					print(p[i])
				end
				if p ~= null and not p.fainted then
					illusion = p
					break
				end
			end
			if not illusion or pokemon == illusion then return end
			pokemon.illusion = illusion
		end,
		-- illusion clearing is hardcoded in the damage function
		-- function because mold breaker inhibits the damage event
		onEnd = function(pokemon)
			if pokemon.illusion then
				self:debug('illusion cleared')
				pokemon.illusion = nil
				--				let details = pokemon.template.species + (pokemon.level === 100 ? '' : ', L' + pokemon.level) + (pokemon.gender === '' ? '' : ', ' + pokemon.gender) + (pokemon.set.shiny ? ', shiny' : '')
				--				this.add('replace', pokemon, details)
				--				this.add('-end', pokemon, 'Illusion')
				self:add('-endability', pokemon, 'Illusion', pokemon.getDetails)
			end
		end,
		onFaint = function(pokemon)
			pokemon.illusion = nil
		end,
		id = "illusion",
		name = "Illusion",
		rating = 4.5,
		num = 149
	},
	['immunity'] = {
		onUpdate = function(pokemon)
			if pokemon.status == 'psn' or pokemon.status == 'tox' then
				pokemon:cureStatus()
			end
		end,
		onImmunity = function(type)
			if type == 'psn' then return false end
		end,
		id = "immunity",
		name = "Immunity",
		rating = 2,
		num = 17
	},
	['imposter'] = {
		onStart = function(pokemon)
			local target = pokemon.side.foe.active[#pokemon.side.foe.active + 1 - pokemon.position]
			if not Not(target) then
				pokemon:transformInto(target, pokemon, self:getAbility('imposter'))
			end
		end,
		id = "imposter",
		name = "Imposter",
		rating = 4.5,
		num = 150
	},
	['infiltrator'] = {
		onModifyMove = function(move)
			move.infiltrates = true
		end,
		id = "infiltrator",
		name = "Infiltrator",
		rating = 3,
		num = 151
	},
	['innerfocus'] = {
		onFlinch = function() return false end,
		id = "innerfocus",
		name = "Inner Focus",
		rating = 1.5,
		num = 39
	},
	['insomnia'] = {
		onUpdate = function(pokemon)
			if pokemon.status == 'slp' then
				pokemon:cureStatus()
			end
		end,
		onImmunity = function(type, pokemon)
			if type == 'slp' then return false end
		end,
		id = "insomnia",
		name = "Insomnia",
		rating = 2,
		num = 15
	},
	['intimidate'] = {
		onStart = function(pokemon)
			local activated = false
			for _, foe in pairs(pokemon.side.foe.active) do
				if foe ~= null and self:isAdjacent(foe, pokemon) then
					if not activated then
						self:add('-ability', pokemon, 'Intimidate')
						activated = true
					end
					if foe.volatiles['substitute'] then
						self:add('-activate', foe, 'Substitute', 'ability = Intimidate', '[of] ' .. pokemon)
					else
						self:boost({atk = -1}, foe, pokemon)
					end
				end
			end
		end,
		id = "intimidate",
		name = "Intimidate",
		rating = 3.5,
		num = 22
	},
	['ironbarbs'] = {
		onAfterDamageOrder = 1,
		onAfterDamage = function(damage, target, source, move)
			if source and source ~= target and move and move.flags['contact'] then
				self:damage(source.maxhp / 8, source, target, nil, true)
			end
		end,
		id = "ironbarbs",
		name = "Iron Barbs",
		rating = 3,
		num = 160
	},
	['ironfist'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if move.flags['punch'] then
				self:debug('Iron Fist boost')
				return self:chainModify(1.4)
			end
		end,
		id = "ironfist",
		name = "Iron Fist",
		rating = 3,
		num = 89
	},
	['justified'] = {
		onAfterDamage = function(damage, target, source, effect)
			if effect and effect.type == 'Dark' then
				self:boost({atk = 1})
			end
		end,
		id = "justified",
		name = "Justified",
		rating = 2,
		num = 154
	},
	['keeneye'] = {
		onBoost = function(boost, target, source, effect)
			if source and target == source then return end
			if boost['accuracy'] and boost['accuracy'] < 0 then
				boost['accuracy'] = 0
				if not effect.secondaries then
					self:add("-fail", target, "unboost", "accuracy", "[from] ability = Keen Eye", "[of] " .. target)
				end
			end
		end,
		onModifyMove = function(move)
			move.ignoreEvasion = true
		end,
		id = "keeneye",
		name = "Keen Eye",
		rating = 1,
		num = 51
	},
	['klutz'] = {
		-- Item suppression implemented in BattlePokemon:ignoringItem()
		id = "klutz",
		name = "Klutz",
		rating = -1,
		num = 103
	},
	['leafguard'] = {
		onSetStatus = function(pokemon)
			if self:isWeather({'sunnyday', 'desolateland'}) then
				return false
			end
		end,
		onTryHit = function(target, source, move)
			if move and move.id == 'yawn' and self:isWeather({'sunnyday', 'desolateland'}) then
				return false
			end
		end,
		id = "leafguard",
		name = "Leaf Guard",
		rating = 1,
		num = 102
	},
	['levitate'] = {
		onImmunity = function(type)
			if type == 'Ground' then return false end
		end,
		id = "levitate",
		name = "Levitate",
		rating = 3.5,
		num = 26
	},
	['lightmetal'] = {
		onModifyWeight = function(weight)
			return weight / 2
		end,
		id = "lightmetal",
		name = "Light Metal",
		rating = 1,
		num = 135
	},
	['lightningrod'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Electric' then
				if not self:boost({spa = 1}) then
					self:add('-immune', target, '[msg]')
				end
				return null
			end
		end,
		onAnyRedirectTargetPriority = 1,
		onAnyRedirectTarget = function(target, source, source2, move)
			if move.type ~= 'Electric' or ({firepledge=true, grasspledge=true, waterpledge=true})[move.id] then return end
			if self:validTarget(self.effectData.target, source, move.target) then
				return self.effectData.target
			end
		end,
		id = "lightningrod",
		name = "Lightning Rod",
		rating = 3.5,
		num = 31
	},

	['limber'] = {
		onUpdate = function(pokemon)
			if pokemon.status == 'par' then
				pokemon:cureStatus()
			end
		end,
		onImmunity = function(type, pokemon)
			if type == 'par' then return false end
		end,
		id = "limber",
		name = "Limber",
		rating = 1.5,
		num = 7
	},
	['liquidooze'] = {
		id = "liquidooze",
		onSourceTryHeal = function(damage, target, source, effect)
			self:debug("Heal is occurring = " .. target .. " <- " .. source .. " : = " .. effect.id)
			local canOoze = {drain=true, leechseed=true}
			if canOoze[effect.id] then
				self:damage(damage, nil, nil, nil, true)
				return 0
			end
		end,
		name = "Liquid Ooze",
		rating = 1.5,
		num = 64
	},
	['magicbounce'] = {
		id = "magicbounce",
		name = "Magic Bounce",
		onTryHitPriority = 1,
		onTryHit = function(target, source, move)
			if target == source or move.hasBounced or not move.flags['reflectable'] then return end
			local newMove = self:getMoveCopy(move.id)
			newMove.hasBounced = true
			self:useMove(newMove, target, source)
			return null
		end,
		onAllyTryHitSide = function(target, source, move)
			if target.side == source.side or move.hasBounced or not move.flags['reflectable'] then return end
			local newMove = self:getMoveCopy(move.id)
			newMove.hasBounced = true
			self:useMove(newMove, target, source)
			return null
		end,
		effect = {
			duration = 1
		},
		rating = 4.5,
		num = 156
	},
	['magicguard'] = {
		onDamage = function(damage, target, source, effect)
			if effect.effectType ~= 'Move' then
				return false
			end
		end,
		id = "magicguard",
		name = "Magic Guard",
		rating = 4.5,
		num = 98
	},
	['magician'] = {
		onSourceHit = function(target, source, move)
			if not move or not target then return end
			if target ~= source and move.category ~= 'Status' then
				if source.item and source.item ~= '' then return end
				local yourItem = target:takeItem(source)
				if Not(yourItem) then return end
				if not source:setItem(yourItem) then
					target.item = yourItem.id -- bypass setItem so we don't break choicelock or anything
					return
				end
				self:add('-item', source, yourItem, '[from] ability = Magician', '[of] ' .. target)
			end
		end,
		id = "magician",
		name = "Magician",
		rating = 1.5,
		num = 170
	},
	['magmaarmor'] = {
		onUpdate = function(pokemon)
			if pokemon.status == 'frz' then
				pokemon:cureStatus()
			end
		end,
		onImmunity = function(type, pokemon)
			if type == 'frz' then return false end
		end,
		id = "magmaarmor",
		name = "Magma Armor",
		rating = 0.5,
		num = 40
	},
	['magnetpull'] = {
		onFoeModifyPokemon = function(pokemon)
			if pokemon:hasType('Steel') and self:isAdjacent(pokemon, self.effectData.target) then
				pokemon:tryTrap(true, self.effectData.target, 'Magnet Pull')
			end
		end,
		onFoeMaybeTrapPokemon = function(pokemon, source)
			if not source then source = self.effectData.target end
			if pokemon:hasType('Steel') and self:isAdjacent(pokemon, source) then
				pokemon.maybeTrapped = true
			end
		end,
		id = "magnetpull",
		name = "Magnet Pull",
		rating = 4.5,
		num = 42
	},
	['marvelscale'] = {
		onModifyDefPriority = 6,
		onModifyDef = function(def, pokemon)
			if pokemon.status then
				return self:chainModify(1.5)
			end
		end,
		id = "marvelscale",
		name = "Marvel Scale",
		rating = 2.5,
		num = 63
	},
	['megalauncher'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if move.flags['pulse'] then
				return self:chainModify(1.5)
			end
		end,
		id = "megalauncher",
		name = "Mega Launcher",
		rating = 3.5,
		num = 178
	},
	['minus'] = {
		onModifySpAPriority = 5,
		onModifySpA = function(spa, pokemon)
			if #pokemon.side.active == 1 then return end
			for _, ally in pairs(pokemon.side.active) do
				if ally and ally.position ~= pokemon.position and not ally.fainted and ally:hasAbility('minus', 'plus') then
					return self:chainModify(1.5)
				end
			end
		end,
		id = "minus",
		name = "Minus",
		rating = 0,
		num = 58
	},
	['moldbreaker'] = {
		onStart = function(pokemon)
			self:add('-ability', pokemon, 'Mold Breaker')
		end,
		stopAttackEvents = true,
		id = "moldbreaker",
		name = "Mold Breaker",
		rating = 3.5,
		num = 104
	},
	['moody'] = {
		onResidualOrder = 26,
		onResidualSubOrder = 1,
		onResidual = function(pokemon)
			local stats = {}
			local boost = {}
			local inc
			for i, b in pairs(pokemon.boosts) do
				if b < 6 then
					table.insert(stats, i)
				end
			end
			if #stats > 0 then
				inc = stats[math.random(#stats)]
				boost[inc] = 2
			end
			stats = {}
			for j, b in pairs(pokemon.boosts) do
				if b > -6 and j ~= inc then
					table.insert(stats, j)
				end
			end
			if #stats > 0 then
				local dec = stats[math.random(#stats)]
				boost[dec] = -1
			end
			self:boost(boost)
		end,
		id = "moody",
		name = "Moody",
		rating = 5,
		num = 141
	},
	['motordrive'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Electric' then
				if not self:boost({spe = 1}) then
					self:add('-immune', target, '[msg]')
				end
				return null
			end
		end,
		id = "motordrive",
		name = "Motor Drive",
		rating = 3,
		num = 78
	},
	['moxie'] = {
		onSourceFaint = function(target, source, effect)
			if effect and effect.effectType == 'Move' then
				self:boost({atk = 1}, source)
			end
		end,
		id = "moxie",
		name = "Moxie",
		rating = 3.5,
		num = 153
	},
	['multiscale'] = {
		onSourceModifyDamage = function(damage, source, target, move)
			if target.hp >= target.maxhp then
				self:debug('Multiscale weaken')
				return self:chainModify(0.5)
			end
		end,
		id = "multiscale",
		name = "Multiscale",
		rating = 4,
		num = 136
	},
	['multitype'] = {
		-- Multitype's type-changing is implemented in Statuses
		onTakeItem = function(item)
			if item.onPlate then return false end
		end,
		id = "multitype",
		name = "Multitype",
		rating = 4,
		num = 121
	},
	['mummy'] = {
		id = "mummy",
		name = "Mummy",
		onAfterDamage = function(damage, target, source, move)
			if source and source ~= target and move and move.flags['contact'] then
				local oldAbility = source:setAbility('mummy', source, 'mummy', true)
				if oldAbility then
					--					self:add('-endability', source, oldAbility, '[from] Mummy')
					--					self:add('-ability', source, 'Mummy', '[from] Mummy')
					self:add('-activate', target, 'ability: Mummy', oldAbility, '[of] ' .. source)
				end
			end
		end,
		rating = 2,
		num = 152
	},
	['naturalcure'] = {
		onSwitchOut = function(pokemon)
			pokemon:setStatus('')
		end,
		onBattleEnd = function(pokemon)
			pokemon:setStatus('')
		end,
		id = "naturalcure",
		name = "Natural Cure",
		rating = 3.5,
		num = 30
	},
	['noguard'] = {
		onAnyAccuracy = function(accuracy, target, source, move)
			if move and (source == self.effectData.target or target == self.effectData.target) then
				return true
			end
			return accuracy
		end,
		id = "noguard",
		name = "No Guard",
		rating = 4,
		num = 99
	},
	['normalize'] = {
		onModifyMovePriority = 1,
		onModifyMove = function(move)
			if move.id ~= 'struggle' then
				move.type = 'Normal'
			end
		end,
		id = "normalize",
		name = "Normalize",
		rating = -1,
		num = 96
	},
	['oblivious'] = {
		onUpdate = function(pokemon)
			if pokemon.volatiles['attract'] then
				pokemon:removeVolatile('attract')
				self:add('-end', pokemon, 'move: Attract', '[from] ability: Oblivious')
			end
			if pokemon.volatiles['taunt'] then
				pokemon:removeVolatile('taunt')
				-- Taunt's volatile already sends the -end message when removed
			end
		end,
		onImmunity = function(type, pokemon)
			if type == 'attract' then
				self:add('-immune', pokemon, '[from] Oblivious')
				return false
			end
		end,
		onTryHit = function(pokemon, target, move)
			if move.id == 'captivate' or move.id == 'taunt' then
				self:add('-immune', pokemon, '[msg]', '[from] Oblivious')
				return null
			end
		end,
		id = "oblivious",
		name = "Oblivious",
		rating = 1,
		num = 12
	},
	['overcoat'] = {
		onImmunity = function(type, pokemon)
			if type == 'sandstorm' or type == 'hail' or type == 'powder' then return false end
		end,
		id = "overcoat",
		name = "Overcoat",
		rating = 2.5,
		num = 142
	},
	['overgrow'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, attacker, defender, move)
			if move.type == 'Grass' then
				self:debug('Overgrow boost')
				return self:chainModify(1.3)
			end
		end,
		onModifySpAPriority = 5,
		onModifySpA = function(atk, attacker, defender, move)
			if move.type == 'Grass' then
				self:debug('Overgrow boost')
				return self:chainModify(1.3)
			end
		end,
		id = "overgrow",
		name = "Overgrow",
		rating = 2,
		num = 65
	},
	['owntempo'] = {
		onUpdate = function(pokemon)
			if pokemon.volatiles['confusion'] then
				pokemon:removeVolatile('confusion')
			end
		end,
		onImmunity = function(type, pokemon)
			if type == 'confusion' then
				self:add('-immune', pokemon, 'confusion')
				return false
			end
		end,
		id = "owntempo",
		name = "Own Tempo",
		rating = 1,
		num = 20
	},
	powerconstruct={
		id='powerconstruct',
		name='Power Construct',
		num=211,
		onResidualOrder=27,
		onResidual = function(pokemon)
			if pokemon.baseSpecies ~= 'Zygarde' and not pokemon.transformed and pokemon.hp <= 0 then return end
			if pokemon.species.id == 'zygardecomplete' and pokemon.hp > pokemon.maxhp / 2 then return end
			if pokemon.hp > pokemon.maxhp/2 then return end
			self:add('-activate', pokemon, 'ability: Power Construct')
			--FORME			
			local template = self:getTemplate('Zygarde-complete')
			pokemon:formeChange(template)
			pokemon.baseTemplate = template
			pokemon.details = template.species .. ', L' .. pokemon.level .. (pokemon.gender == '' and '' or ', ') .. pokemon.gender .. (pokemon.set.shiny and ', shiny' or '')
			self:add('detailschange', pokemon, pokemon.details, '[powerconstruct]', '[icon] '..(template.icon or 0))
			local shinyPrefix = pokemon.shiny and '_SHINY' or ''
			self:setupDataForTransferToPlayers('Sprite', shinyPrefix..'_FRONT/Zygarde-complete')
			self:setupDataForTransferToPlayers('Sprite', shinyPrefix..'_BACK/Zygarde-complete')

			pokemon.iconOverride = template.icon-1
			-- is there a better way to access this?
			pokemon.frontSpriteOverride = require(game:GetService('ServerStorage').Data.GifData)[shinyPrefix..'_FRONT']['Zygarde-complete']
			pokemon.baseStatOverride = template.baseStats
			--FORME
			--self:add('-formechange', pokemon, 'Zygarde-Complete')
			pokemon.baseMaxhp = math.floor(math.floor(2*pokemon.template.baseStats[1] + pokemon.set.ivs[1] + math.floor(pokemon.set.evs[1]/4) + 100) * pokemon.level/100+10) -- 1 = hp
			local newMaxHP = (pokemon.volatiles['dynamax'] and 2*pokemon.baseMaxhp or pokemon.baseMaxhp)
			pokemon.maxhp = newMaxHP
			pokemon.hp = newMaxHP - (pokemon.maxhp - pokemon.hp)
			self:heal(pokemon.hp)
		end
	},
	schooling = {
		onStart = function(pokemon) 
			if pokemon.template.species == 'Wishiwashi' and pokemon.level >= 20 and pokemon.hp > pokemon.maxhp / 4 and not pokemon.schooling and pokemon:formeChange('Wishiwashi-School') then 
				pokemon.schooling = true
				self:add('-formechange', pokemon, 'Wishiwashi-School')
			end
		end,
		onResidualOrder = 27,
		onResidual = function(pokemon) 
			if pokemon.template.species == 'Wishiwashi' and pokemon.level >= 20 then 
				if pokemon.hp > pokemon.maxhp / 4 and not pokemon.schooling then
					if pokemon:formeChange('Wishiwashi-School') then
						pokemon.schooling = true
						self:add('-formechange', pokemon, 'Wishiwashi-School')
					end
				elseif pokemon.hp <= pokemon.maxhp / 4 and pokemon.schooling then
					if pokemon:formeChange('Wishiwashi') then
						pokemon.schooling = false
						self:add('-formechange', pokemon, 'Wishiwashi')
					end
				end
			end
		end,

		name = "Schooling",
		rating = 3,
		num = 208,
		id = 'schooling'
	},
	['sharpness'] = {
		onBasePowerPriority = 19,
		onBasePower = function(basePower, attacker, defender, move)
			if move.flags['blademaster'] then
				self:debug('Sharpness boost')
				return self:chainModify(1.5)
			end
		end,
		id = "sharpness",
		name = "Sharpness",
		rating = 3,
		num = 267
	},
	['galvanize'] = {
		onModifyMovePriority = -1,
		onModifyMove = function(move, pokemon)
			if move.type == 'Normal' and move.id ~= 'naturalgift' then
				move.type = 'Electric'
				if move.category ~= 'Status' then
					pokemon:addVolatile('galvanize')
				end
			end
		end,
		effect = {
			duration = 1,
			onBasePowerPriority = 8,
			onBasePower = function(basePower, pokemon, target, move)
				return self:chainModify(0x1333, 0x1000)
			end
		},
		id = 'galvanize',
		name = "Galvanize",
		rating = 4,
		num = 206,
	},
	['surgesurfer'] = {
		onModifySpe = function(spe)
			if (self:isTerrain('electricterrain')) then
				return self:chainModify(2)
			end
		end,
		id = 'surgesurfer',
		name = "Surge Surfer",
		rating = 3,
		num = 207,
	},
	['parentalbond'] = {
		onPrepareHit = function(source, target, move)
			if move.id == 'iceball' or move.id == 'rollout' then return end
			if move.category ~= 'Status' and not move.selfdestruct and not move.multihit and not move.flags['charge'] and not move.spreadHit then
				move.multihit = 2
				source:addVolatile('parentalbond')
			end
		end,
		effect = {
			duration = 1,
			onBasePowerPriority = 8,
			onBasePower = function(basePower)
				if self.effectData.hit then
					return self:chainModify(0.25)
				else
					self.effectData.hit = true
				end
			end
		},
		id = "parentalbond",
		name = "Parental Bond",
		rating = 4,
		num = 184
	},

	['pickup'] = {
		onResidualOrder = 26,
		onResidualSubOrder = 1,
		onResidual = function(pokemon)
			if pokemon.item and pokemon.item ~= '' then return end
			local pickupTargets = {}
			for _, side in pairs(self.sides) do
				for _, target in pairs(side.active) do
					if target ~= null and (target.lastItem and target.lastItem ~= '') and target.usedItemThisTurn and self:isAdjacent(pokemon, target) then
						table.insert(pickupTargets, target)
					end
				end
			end
			if #pickupTargets == 0 then return end
			local target = pickupTargets[math.random(#pickupTargets)]
			pokemon:setItem(target.lastItem)
			target.lastItem = ''
			local item = pokemon:getItem()
			self:add('-item', pokemon, item, '[from] Pickup')
			if item.isBerry then pokemon:update() end
		end,
		id = "pickup",
		name = "Pickup",
		rating = 0.5,
		num = 53
	},
	['pickpocket'] = {
		onAfterMoveSecondary = function(target, source, move)
			if source and source ~= target and move and move.flags['contact'] then
				if target.item and target.item ~= '' then return end
				local yourItem = source:takeItem(target)
				if Not(yourItem) then return end
				if not target:setItem(yourItem) then
					source.item = yourItem.id
					return
				end
				self:add('-item', target, yourItem, '[from] ability = Pickpocket', '[of] ' .. source)
			end
		end,
		id = "pickpocket",
		name = "Pickpocket",
		rating = 1,
		num = 124
	},
	['pixilate'] = {
		onModifyMovePriority = -1,
		onModifyMove = function(move, pokemon)
			if move.type == 'Normal' and move.id ~= 'naturalgift' then
				move.type = 'Fairy'
				if move.category ~= 'Status' then
					pokemon:addVolatile('pixilate')
				end
			end
		end,
		effect = {
			duration = 1,
			onBasePowerPriority = 8,
			onBasePower = function(basePower, pokemon, target, move)
				return self:chainModify(0x1333, 0x1000)
			end
		},
		id = "pixilate",
		name = "Pixilate",
		rating = 3.5,
		num = 182
	},
	['plus'] = {
		onModifySpAPriority = 5,
		onModifySpA = function(spa, pokemon)
			if #pokemon.side.active == 1 then return end
			for _, ally in pairs(pokemon.side.active) do
				if ally ~= null and ally.position ~= pokemon.position and not ally.fainted and ally:hasAbility('minus', 'plus') then
					return self:chainModify(1.5)
				end
			end
		end,
		id = "plus",
		name = "Plus",
		rating = 0,
		num = 57
	},
	['poisonheal'] = {
		onDamage = function(damage, target, source, effect)
			if effect.id == 'psn' or effect.id == 'tox' then
				self:heal(target.maxhp / 8)
				return false
			end
		end,
		id = "poisonheal",
		name = "Poison Heal",
		rating = 4,
		num = 90
	},
	['poisonpoint'] = {
		onAfterDamage = function(damage, target, source, move)
			if move and move.flags['contact'] then
				if math.random(10) <= 3 then
					self.statusSourceMessage = {'-ability', target, 'poisonpoint'}
					source:trySetStatus('psn', target, move)
					self.statusSourceMessage = nil
				end
			end
		end,
		id = "poisonpoint",
		name = "Poison Point",
		rating = 2,
		num = 38
	},
	['poisontouch'] = {
		onModifyMove = function(move)
			if not move or not move.flags['contact'] then return end
			if not move.secondaries then
				move.secondaries = {}
			end
			table.insert(move.secondaries, {
				chance = 30,
				status = 'psn'
			})
		end,
		id = "poisontouch",
		name = "Poison Touch",
		rating = 2,
		num = 143
	},
	['prankster'] = {
		onModifyPriority = function(priority, pokemon, target, move)
			if move and move.category == 'Status' and not target:hasType ("Dark") then
				return priority + 1	
			elseif move and move.category == 'Status' and target:hasType ("Dark") and 
				not move.volatileStatus then
				return priority + 1,
				target:addVolatile('prankster')
			elseif target:hasType ("Dark") then
				if move.volatileStatus and move.category == 'Status' then
					move.volatileStatus = nil 					
					return 
				end
			end
		end,
		id = "prankster",
		name = "Prankster",
		rating = 4,--dropped it not as good as before due to gen 7 nerf!.
		num = 158
	},

	['pressure'] = {
		onStart = function(pokemon)
			self:add('-ability', pokemon, 'Pressure')
		end,
		onDeductPP = function(target, source)
			if target.side == source.side then return end
			return 1
		end,
		id = "pressure",
		name = "Pressure",
		rating = 1.5,
		num = 46
	},
	['primordialsea'] = {
		onStart = function(source)
			self:setWeather('primordialsea')
		end,
		onAnySetWeather = function(target, source, weather)
			local allowedWeathers = {deltastream = true, desolateland = true, none = true}
			if self:getWeather().id == 'primordialsea' and not allowedWeathers[weather.id] then
				return false
			end
		end,
		onEnd = function(pokemon)
			if self.weatherData.source ~= pokemon then
				return
			end
			local hasPrimordialSeaAbility = false
			for _, side in pairs(self.sides) do
				for _, target in pairs(side.active) do
					if target and target ~= pokemon and target.hp > 0 and target:getAbility().id == 'primordialsea' then
						self.weatherData.source = target
						hasPrimordialSeaAbility = true
						break
					end
				end
				if hasPrimordialSeaAbility then
					break
				end
			end
			if not hasPrimordialSeaAbility then
				self.weatherData.duration = 0 -- Reset the weather duration to 0
				self.weather = nil -- Clear the weather
			end
		end,
		id = "primordialsea",
		name = "Primordial Sea",
		rating = 5,
		num = 189
	},
	['protean'] = {
		onPrepareHit = function(source, target, move)
			local type = move.type
			if type and type ~= '???' and table.concat(source:getTypes(), '') ~= type then
				if not source:setType(type) then return end
				self:add('-start', source, 'typechange', type, '[from] Protean')
			end
		end,
		id = "protean",
		name = "Protean",
		rating = 4,
		num = 168
	},
	['purepower'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk)
			return self:chainModify(2)
		end,
		id = "purepower",
		name = "Pure Power",
		rating = 5,
		num = 74
	},
	['quickfeet'] = {
		onModifySpe = function(spe, pokemon)
			if pokemon.status and pokemon.status ~= '' then
				return self:chainModify(1.5)
			end
		end,
		id = "quickfeet",
		name = "Quick Feet",
		rating = 2.5,
		num = 95
	},
	['raindish'] = {
		onWeather = function(target, source, effect)
			if effect.id == 'raindance' or effect.id == 'primordialsea' then
				self:heal(target.maxhp / 16)
			end
		end,
		id = "raindish",
		name = "Rain Dish",
		rating = 1.5,
		num = 44
	},
	['rattled'] = {
		onAfterDamage = function(damage, target, source, effect)
			if effect and (effect.type == 'Dark' or effect.type == 'Bug' or effect.type == 'Ghost') then
				self:boost({spe = 1})
			end
		end,
		id = "rattled",
		name = "Rattled",
		rating = 1.5,
		num = 155
	},
	['reckless'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if move.recoil or move.hasCustomRecoil then
				self:debug('Reckless boost')
				return self:chainModify(0x1333, 0x1000)
			end
		end,
		id = "reckless",
		name = "Reckless",
		rating = 3,
		num = 120
	},
	['refrigerate'] = {
		onModifyMovePriority = -1,
		onModifyMove = function(move, pokemon)
			if move.type == 'Normal' and move.id ~= 'naturalgift' then
				move.type = 'Ice'
				if move.category ~= 'Status' then
					pokemon:addVolatile('refrigerate')
				end
			end
		end,
		effect = {
			duration = 1,
			onBasePowerPriority = 8,
			onBasePower = function(basePower, pokemon, target, move)
				return self:chainModify(0x1333, 0x1000)
			end
		},
		id = "refrigerate",
		name = "Refrigerate",
		rating = 4,
		num = 174
	},

	['regenerator'] = {
		onSwitchOut = function(pokemon)
			pokemon:heal(pokemon.maxhp / 3)
		end,
		id = "regenerator",
		name = "Regenerator",
		rating = 4,
		num = 144
	},
	['rivalry'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if attacker.gender and attacker.gender ~= '' and defender.gender and defender.gender ~= '' then
				if attacker.gender == defender.gender then
					self:debug('Rivalry boost')
					return self:chainModify(1.25)
				end
			end
		end,
		id = "rivalry",
		name = "Rivalry",
		rating = 1.5,
		num = 79
	},
	['rockhead'] = {
		onDamage = function(damage, target, source, effect)
			if effect.id == 'recoil' and self.activeMove.id ~= 'struggle' then return null end
		end,
		id = "rockhead",
		name = "Rock Head",
		rating = 3,
		num = 69
	},
	['roughskin'] = {
		onAfterDamageOrder = 1,
		onAfterDamage = function(damage, target, source, move)
			if source and source ~= target and move and move.flags['contact'] then
				self:damage(source.maxhp / 8, source, target, nil, true)
			end
		end,
		id = "roughskin",
		name = "Rough Skin",
		rating = 3,
		num = 24
	},
	['runaway'] = {
		id = "runaway",
		name = "Run Away",
		rating = 0,
		num = 50
	},
	['sandforce'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if self:isWeather('sandstorm') then
				if move.type == 'Rock' or move.type == 'Ground' or move.type == 'Steel' then
					self:debug('Sand Force boost')
					return self:chainModify(0x14CD, 0x1000)
				end
			end
		end,
		onImmunity = function(type, pokemon)
			if type == 'sandstorm' then return false end
		end,
		id = "sandforce",
		name = "Sand Force",
		rating = 2,
		num = 159
	},


	['sandrush'] = {
		onModifySpe = function(spe, pokemon)
			if self:isWeather('sandstorm') then
				return self:chainModify(2)
			end
		end,
		onImmunity = function(type, pokemon)
			if type == 'sandstorm' then return false end
		end,
		id = "sandrush",
		name = "Sand Rush",
		rating = 2.5,
		num = 146
	},
	['sandstream'] = {
		onStart = function(source)
			self:setWeather('sandstorm')
		end,
		id = "sandstream",
		name = "Sand Stream",
		rating = 4,
		num = 45
	},


	['sandveil'] = {
		onImmunity = function(type, pokemon)
			if type == 'sandstorm' then return false end
		end,
		onModifyAccuracy = function(accuracy)
			if type(accuracy) ~= 'number' then return end
			if self:isWeather('sandstorm') then
				self:debug('Sand Veil - decreasing accuracy')
				return accuracy * 0.8
			end
		end,
		id = "sandveil",
		name = "Sand Veil",
		rating = 1.5,
		num = 8
	},
	['sapsipper'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Grass' then
				if not self:boost({atk = 1}) then
					self:add('-immune', target, '[msg]')
				end
				return null
			end
		end,
		onAllyTryHitSide = function(target, source, move)
			if target == self.effectData.target or target.side ~= source.side then return end
			if move.type == 'Grass' then
				self:boost({atk = 1}, self.effectData.target)
			end
		end,
		id = "sapsipper",
		name = "Sap Sipper",
		rating = 3.5,
		num = 157
	},
	['scrappy'] = {
		onModifyMovePriority = -5,
		onModifyMove = function(move)
			if not move.ignoreImmunity then move.ignoreImmunity = {} end
			if move.ignoreImmunity ~= true then
				move.ignoreImmunity['Fighting'] = true
				move.ignoreImmunity['Normal'] = true
			end
		end,
		id = "scrappy",
		name = "Scrappy",
		rating = 3,
		num = 113
	},
	['serenegrace'] = {
		onModifyMovePriority = -2,
		onModifyMove = function(move)
			if move.secondaries and move.id ~= 'secretpower' then
				self:debug('doubling secondary chance')
				for _, s in pairs(move.secondaries) do
					s.chance = s.chance * 2
				end
			end
		end,
		id = "serenegrace",
		name = "Serene Grace",
		rating = 4,
		num = 32
	},
	['shadowtag'] = {
		onFoeModifyPokemon = function(pokemon)
			if not pokemon:hasAbility('shadowtag') and self:isAdjacent(pokemon, self.effectData.target) then
				pokemon:tryTrap(true, self.effectData.target, 'Shadow Tag')
			end
		end,
		onFoeMaybeTrapPokemon = function(pokemon, source)
			if not source then source = self.effectData.target end
			if not pokemon:hasAbility('shadowtag') and self:isAdjacent(pokemon, source) then
				pokemon.maybeTrapped = true
			end
		end,
		id = "shadowtag",
		name = "Shadow Tag",
		rating = 5,
		num = 23
	},
	['shedskin'] = {
		onResidualOrder = 5,
		onResidualSubOrder = 1,
		onResidual = function(pokemon)
			if pokemon.hp and (pokemon.status and pokemon.status ~= '') and math.random(3) == 1 then
				self:debug('shed skin')
				self:add('-activate', pokemon, 'ability = Shed Skin')
				pokemon:cureStatus()
			end
		end,
		id = "shedskin",
		name = "Shed Skin",
		rating = 3.5,
		num = 61
	},
	['sheerforce'] = {
		onModifyMove = function(move, pokemon)
			if move.secondaries then
				move.secondaries = nil
				-- Negation of `AfterMoveSecondary` effects implemented in Extension
				pokemon:addVolatile('sheerforce')
			end
		end,
		effect = {
			duration = 1,
			onBasePowerPriority = 8,
			onBasePower = function(basePower, pokemon, target, move)
				return self:chainModify(0x14CD, 0x1000)
			end
		},
		id = "sheerforce",
		name = "Sheer Force",
		rating = 4,
		num = 125
	},
	['shellarmor'] = {
		onCriticalHit = function() return false end,
		id = "shellarmor",
		name = "Shell Armor",
		rating = 1,
		num = 75
	},
	['shielddust'] = {
		onModifySecondaries = function(secondaries)
			self:debug('Shield Dust prevent secondary')
			return filter(secondaries, function(effect)
				return effect.self and true or false
			end)
		end,
		id = "shielddust",
		name = "Shield Dust",
		rating = 2.5,
		num = 19
	},
	['simple'] = {
		onBoost = function(boost)
			for i, b in pairs(boost) do
				boost[i] = b * 2
			end
		end,
		id = "simple",
		name = "Simple",
		rating = 4,
		num = 86
	},
	['skilllink'] = {
		onModifyMove = function(move)
			if move.multihit and type(move.multihit) == 'table' then
				move.multihit = move.multihit[2]
			end
		end,
		id = "skilllink",
		name = "Skill Link",
		rating = 4,
		num = 92
	},
	['slowstart'] = {
		onStart = function(pokemon)
			pokemon:addVolatile('slowstart')
		end,
		onEnd = function(pokemon)
			pokemon.volatiles['slowstart'] = nil
			self:add('-end', pokemon, 'Slow Start', '[silent]')
		end,
		effect = {
			duration = 5,
			onStart = function(target)
				self:add('-start', target, 'Slow Start')
			end,
			onModifyAtkPriority = 5,
			onModifyAtk = function(atk, pokemon)
				return self:chainModify(0.5)
			end,
			onModifySpe = function(spe, pokemon)
				return self:chainModify(0.5)
			end,
			onEnd = function(target)
				self:add('-end', target, 'Slow Start')
			end
		},
		id = "slowstart",
		name = "Slow Start",
		rating = -2,
		num = 112
	},
	['sniper'] = {
		onModifyDamage = function(damage, source, target, move)
			if move.crit then
				self:debug('Sniper boost')
				return self:chainModify(1.5)
			end
		end,
		id = "sniper",
		name = "Sniper",
		rating = 1,
		num = 97
	},
	['snowcloak'] = {
		onImmunity = function(type, pokemon)
			if type == 'hail' then return false end
		end,
		onModifyAccuracy = function(accuracy)
			if type(accuracy) ~= 'number' then return end
			if self:isWeather('hail') then
				self:debug('Snow Cloak - decreasing accuracy')
				return accuracy * 0.8
			end
		end,
		id = "snowcloak",
		name = "Snow Cloak",
		rating = 1.5,
		num = 81
	},
	['snowwarning'] = {
		onStart = function(source)
			self:setWeather('hail')
		end,
		id = "snowwarning",
		name = "Snow Warning",
		rating = 3.5,
		num = 117
	},
	['solarpower'] = {
		onModifySpAPriority = 5,
		onModifySpA = function(spa, pokemon)
			if self:isWeather({'sunnyday', 'desolateland'}) then
				return self:chainModify(1.5)
			end
		end,
		id = "solarpower",
		name = "Solar Power",
		rating = 2,
		num = 94
	},
	['solidrock'] = {
		onSourceModifyDamage = function(damage, source, target, move)
			if move.typeMod > 0 then --if self:getEffectiveness(move, target) > 1 then
				self:debug('Solid Rock neutralize')
				return self:chainModify(0.75)
			end
		end,
		id = "solidrock",
		name = "Solid Rock",
		rating = 3,
		num = 116
	},
	['soundproof'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.flags['sound'] then
				self:add('-immune', target, '[msg]')
				return null
			end
		end,
		id = "soundproof",
		name = "Soundproof",
		rating = 2,
		num = 43
	},
	['speedboost'] = {
		onResidualOrder = 26,
		onResidualSubOrder = 1,
		onResidual = function(pokemon)
			if pokemon.activeTurns and pokemon.activeTurns > 0 then
				self:boost({spe = 1})
			end
		end,
		id = "speedboost",
		name = "Speed Boost",
		rating = 4.5,
		num = 3
	},
	['stall'] = {
		onModifyPriority = function(priority)
			return priority - 0.1
		end,
		id = "stall",
		name = "Stall",
		rating = -1,
		num = 100
	},
	['stancechange'] = {
		onBeforeMovePriority = 11,
		onBeforeMove = function(pokemon, target, move)
			if pokemon.template.species ~= 'Aegislash' then return end
			if move.category ~= 'Status' then
				if Not(pokemon.template.forme) and pokemon:formeChange('Aegislash-Blade') then
					self:add('-formechange', pokemon, 'Aegislash-Blade')
				end
			elseif move.id == 'kingsshield' then
				if pokemon.template.forme == 'Blade' and pokemon:formeChange('Aegislash') then
					self:add('-formechange', pokemon, 'Aegislash')
				end
			end
		end,
		id = "stancechange",
		name = "Stance Change",
		rating = 5,
		num = 176
	},
	['static'] = {
		onAfterDamage = function(damage, target, source, effect)
			if effect and effect.flags['contact'] then
				if math.random(10) <= 3 then
					self.statusSourceMessage = {'-ability', target, 'static'}
					source:trySetStatus('par', target, effect)
					self.statusSourceMessage = nil
				end
			end
		end,
		id = "static",
		name = "Static",
		rating = 2,
		num = 9
	},
	['steadfast'] = {
		onFlinch = function(pokemon)
			self:boost({spe = 1})
		end,
		id = "steadfast",
		name = "Steadfast",
		rating = 1,
		num = 80
	},
	['stench'] = {
		onModifyMove = function(move)
			if move.category ~= "Status" then
				self:debug('Adding Stench flinch')
				if not move.secondaries then move.secondaries = {} end
				for _, s in pairs(move.secondaries) do
					if s.volatileStatus == 'flinch' then return end
				end
				table.insert(move.secondaries, {
					chance = 10,
					volatileStatus = 'flinch'
				})
			end
		end,
		id = "stench",
		name = "Stench",
		rating = 0.5,
		num = 1
	},
	['stickyhold'] = {
		onTakeItem = function(item, pokemon, source)
			if self:suppressingAttackEvents() and pokemon ~= self.activePokemon then return end
			if (source and source ~= pokemon) or self.activeMove.id == 'knockoff' then
				self:add('-activate', pokemon, 'ability: Sticky Hold')
				return false
			end
		end,
		id = "stickyhold",
		name = "Sticky Hold",
		rating = 1.5,
		num = 60
	},
	['stormdrain'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Water' and move.id ~= 'snipeshot' then
				if not self:boost({spa = 1}) then
					self:add('-immune', target, '[msg]')
				end
				return null
			end
		end,
		onAnyRedirectTargetPriority = 1,
		onAnyRedirectTarget = function(target, source, source2, move)
			if move.type ~= 'Water' or ({firepledge=true, grasspledge=true, waterpledge=true})[move.id] then return end
			if self:validTarget(self.effectData.target, source, move.target) then
				move.accuracy = true
				return self.effectData.target
			end
		end,
		id = "stormdrain",
		name = "Storm Drain",
		rating = 3.5,
		num = 114
	},

	['strongjaw'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if move.flags['bite'] then
				return self:chainModify(1.5)
			end
		end,
		id = "strongjaw",
		name = "Strong Jaw",
		rating = 3,
		num = 173
	},
	['sturdy'] = {
		onTryHit = function(pokemon, target, move)
			if move.ohko then
				self:add('-immune', pokemon, '[msg]')
				return null
			end
		end,
		onDamagePriority = -100,
		onDamage = function(damage, target, source, effect)
			if target.hp == target.maxhp and damage >= target.hp and effect and effect.effectType == 'Move' then
				self:add('-ability', target, 'Sturdy')
				return target.hp - 1
			end
		end,
		id = "sturdy",
		name = "Sturdy",
		rating = 3,
		num = 5
	},
	['suctioncups'] = {
		onDragOutPriority = 1,
		onDragOut = function(pokemon)
			self:add('-activate', pokemon, 'ability = Suction Cups')
			return null
		end,
		id = "suctioncups",
		name = "Suction Cups",
		rating = 2,
		num = 21
	},
	['superluck'] = {
		onModifyMove = function(move)
			move.critRatio = move.critRatio + 1
		end,
		id = "superluck",
		name = "Super Luck",
		rating = 1.5,
		num = 105
	},
	['swarm'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, attacker, defender, move)
			if move.type == 'Bug' then
				self:debug('Swarm boost')
				return self:chainModify(1.3)
			end
		end,
		onModifySpAPriority = 5,
		onModifySpA = function(atk, attacker, defender, move)
			if move.type == 'Bug' then
				self:debug('Swarm boost')
				return self:chainModify(1.3)
			end
		end,
		id = "swarm",
		name = "Swarm",
		rating = 2,
		num = 68
	},
	['sweetveil'] = {
		id = "sweetveil",
		name = "Sweet Veil",
		onAllySetStatus = function(status, target, source, effect)
			if status.id == 'slp' then
				self:debug('Sweet Veil interrupts sleep')
				return false
			end
		end,
		onAllyTryHit = function(target, source, move)
			if move and move.id == 'yawn' then
				self:debug('Sweet Veil blocking yawn')
				return false
			end
		end,
		rating = 2,
		num = 175
	},
	['swiftswim'] = {
		onModifySpe = function(spe, pokemon)
			if self:isWeather({'raindance', 'primordialsea'}) then
				return self:chainModify(2)
			end
		end,
		id = "swiftswim",
		name = "Swift Swim",
		rating = 2.5,
		num = 33
	},
	['symbiosis'] = {
		onAllyAfterUseItem = function(item, pokemon)
			local sourceItem = self.effectData.target:getItem()
			local noSharing = sourceItem.onTakeItem and sourceItem.onTakeItem(sourceItem, pokemon) == false
			if (not sourceItem or sourceItem == '') or noSharing then return end
			sourceItem = self.effectData.target:takeItem()
			if Not(sourceItem) then return end
			if pokemon:setItem(sourceItem) then
				self:add('-activate', pokemon, 'ability = Symbiosis', sourceItem, '[of] ' .. self.effectData.target)
			end
		end,
		id = "symbiosis",
		name = "Symbiosis",
		rating = 0,
		num = 180
	},
	['synchronize'] = {
		onAfterSetStatus = function(status, target, source, effect)
			if not source or source == target then return end
			if effect and effect.id == 'toxicspikes' then return end
			if status.id == 'slp' or status.id == 'frz' then return end
			source:trySetStatus(status, target)
		end,
		id = "synchronize",
		name = "Synchronize",
		rating = 2.5,
		num = 28
	},
	['tangledfeet'] = {
		id = "tangledfeet",
		name = "Tangled Feet",
		rating = 1,
		num = 77
	},
	['technician'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if basePower <= 60 then
				self:debug('Technician boost')
				return self:chainModify(1.5)
			end
		end,
		id = "technician",
		name = "Technician",
		rating = 4,
		num = 101
	},
	['telepathy'] = {
		onTryHit = function(target, source, move)
			if target ~= source and target.side == source.side and move.category ~= 'Status' then
				self:add('-activate', target, 'ability = Telepathy')
				return null
			end
		end,
		id = "telepathy",
		name = "Telepathy",
		rating = 0,
		num = 140
	},
	['teravolt'] = {
		onStart = function(pokemon)
			self:add('-ability', pokemon, 'Teravolt')
		end,
		stopAttackEvents = true,
		id = "teravolt",
		name = "Teravolt",
		rating = 3.5,
		num = 164
	},
	['thickfat'] = {
		onModifyAtkPriority = 6,
		onSourceModifyAtk = function(atk, attacker, defender, move)
			if move.type == 'Ice' or move.type == 'Fire' then
				self:debug('Thick Fat weaken')
				return self:chainModify(0.5)
			end
		end,
		onModifySpAPriority = 5,
		onSourceModifySpA = function(atk, attacker, defender, move)
			if move.type == 'Ice' or move.type == 'Fire' then
				self:debug('Thick Fat weaken')
				return self:chainModify(0.5)
			end
		end,
		id = "thickfat",
		name = "Thick Fat",
		rating = 3.5,
		num = 47
	},
	['tintedlens'] = {
		onModifyDamage = function(damage, source, target, move)
			if move.typeMod < 0 then --if self:getEffectiveness(move, target) < 1 then
				self:debug('Tinted Lens boost')
				return self:chainModify(2)
			end
		end,
		id = "tintedlens",
		name = "Tinted Lens",
		rating = 4,
		num = 110
	},
	['torrent'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, attacker, defender, move)
			if move.type == 'Water' then
				self:debug('Torrent boost')
				return self:chainModify(1.3)
			end
		end,
		onModifySpAPriority = 5,
		onModifySpA = function(atk, attacker, defender, move)
			if move.type == 'Water' then
				self:debug('Torrent boost')
				return self:chainModify(1.3)
			end
		end,
		id = "torrent",
		name = "Torrent",
		rating = 2,
		num = 67
	},
	['toxicboost'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if (attacker.status == 'psn' or attacker.status == 'tox') and move.category == 'Physical' then
				return self:chainModify(1.5)
			end
		end,
		id = "toxicboost",
		name = "Toxic Boost",
		rating = 3,
		num = 137
	},
	['toughclaws'] = {
		onBasePowerPriority = 8,
		onBasePower = function(basePower, attacker, defender, move)
			if move.flags['contact'] then
				return self:chainModify(0x14CD, 0x1000)
			end
		end,
		id = "toughclaws",
		name = "Tough Claws",
		rating = 3.5,
		num = 181
	},
	['trace'] = {
		onUpdate = function(pokemon)
			local possibleTargets = {}
			for _, foe in pairs(pokemon.side.foe.active) do
				if foe ~= null and not foe.fainted then
					table.insert(possibleTargets, foe)
				end
			end
			while #possibleTargets > 0 do
				local rand = 1
				if #possibleTargets > 1 then
					rand = math.random(#possibleTargets)
				end
				local target = possibleTargets[rand]
				local ability = self:getAbility(target.ability)
				local bannedAbilities = {flowergift=true, forecast=true, illusion=true, imposter=true, multitype=true, stancechange=true, trace=true, zenmode=true}
				if bannedAbilities[target.ability] then
					table.remove(possibleTargets, rand)
				else
					self:add('-ability', pokemon, ability, '[from] ability = Trace', '[of] ' .. target)
					pokemon:setAbility(ability)
					return
				end
			end
		end,
		id = "trace",
		name = "Trace",
		rating = 3,
		num = 36
	},
	['truant'] = {
		onBeforeMovePriority = 9,
		onBeforeMove = function(pokemon, target, move)
			if pokemon:removeVolatile('truant') then
				self:add('cant', pokemon, 'ability = Truant', move)
				return false
			end
			pokemon:addVolatile('truant')
		end,
		effect = {
			duration = 2
		},
		id = "truant",
		name = "Truant",
		rating = -2,
		num = 54
	},
	['turboblaze'] = {
		onStart = function(pokemon)
			self:add('-ability', pokemon, 'Turboblaze')
		end,
		stopAttackEvents = true,
		id = "turboblaze",
		name = "Turboblaze",
		rating = 3.5,
		num = 163
	},
	['unaware'] = {
		id = "unaware",
		name = "Unaware",
		onAnyModifyBoost = function(boosts, target)
			local source = self.effectData.target
			if source == target then return end
			if source == self.activePokemon and target == self.activeTarget then
				boosts['def'] = 0
				boosts['spd'] = 0
				boosts['evasion'] = 0
			end
			if target == self.activePokemon and source == self.activeTarget then
				boosts['atk'] = 0
				boosts['spa'] = 0
				boosts['accuracy'] = 0
			end
		end,
		rating = 3,
		num = 109
	},
	['unburden'] = {
		onAfterUseItem = function(item, pokemon)
			if pokemon ~= self.effectData.target then return end
			pokemon:addVolatile('unburden')
		end,
		onTakeItem = function(item, pokemon)
			pokemon:addVolatile('unburden')
		end,
		onEnd = function(pokemon)
			pokemon:removeVolatile('unburden')
		end,
		effect = {
			onModifySpe = function(spe, pokemon)
				if not pokemon.item or pokemon.item == '' then
					return self:chainModify(2)
				end
			end
		},
		id = "unburden",
		name = "Unburden",
		rating = 3.5,
		num = 84
	},
	['unnerve'] = {
		onStart = function(pokemon)
			self:add('-ability', pokemon, 'Unnerve', pokemon.side.foe)
		end,
		onFoeEatItem = function() return false end,
		id = "unnerve",
		name = "Unnerve",
		rating = 1.5,
		num = 127
	},
	['victorystar'] = {
		onAllyModifyMove = function(move)
			if type(move.accuracy) == 'number' then
				move.accuracy = move.accuracy * 1.3
			end
		end,
		id = "victorystar",
		name = "Victory Star",
		rating = 2.5,
		num = 162
	},
	['vitalspirit'] = {
		onUpdate = function(pokemon)
			if pokemon.status == 'slp' then
				pokemon:cureStatus()
			end
		end,
		onImmunity = function(type)
			if type == 'slp' then return false end
		end,
		id = "vitalspirit",
		name = "Vital Spirit",
		rating = 2,
		num = 72
	},
	['voltabsorb'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Electric' then
				if Not(self:heal(target.maxhp / 4)) then
					self:add('-immune', target, '[msg]')
				end
				return null
			end
		end,
		id = "voltabsorb",
		name = "Volt Absorb",
		rating = 3.5,
		num = 10
	},
	['waterabsorb'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Water' and move.id ~= 'snipeshot' then
				if Not(self:heal(target.maxhp / 4)) then
					self:add('-immune', target, '[msg]')
				end
				return null
			end
		end,
		id = "waterabsorb",
		name = "Water Absorb",
		rating = 3.5,
		num = 11
	},
	['waterveil'] = {
		onUpdate = function(pokemon)
			if pokemon.status == 'brn' then
				pokemon:cureStatus()
			end
		end,
		onImmunity = function(type, pokemon)
			if type == 'brn' then return false end
		end,
		id = "waterveil",
		name = "Water Veil",
		rating = 2,
		num = 41
	},
	['weakarmor'] = {
		onAfterDamage = function(damage, target, source, move)
			if move.category == 'Physical' then
				self:boost({def = -1, spe = 2})
			end
		end,
		id = "weakarmor",
		name = "Weak Armor",
		rating = 0.5,
		num = 133
	},
	['whitesmoke'] = {
		onBoost = function(boost, target, source, effect)
			if source and target == source then return end
			local showMsg = false
			for i, b in pairs(boost) do
				if b < 0 then
					boost[i] = nil
					showMsg = true
				end
			end
			if showMsg and not effect.secondaries then
				self:add("-fail", target, "unboost", "[from] ability = White Smoke", "[of] " .. target)
			end
		end,
		id = "whitesmoke",
		name = "White Smoke",
		rating = 2,
		num = 73
	},
	['wonderguard'] = {
		onTryHit = function(target, source, move)
			if target == source or move.category == 'Status' or move.type == '???' or move.id == 'struggle' or move.isFutureMove then return end
			self:debug('Wonder Guard immunity = ' .. move.id)
			if target:runEffectiveness(move) <= 1 then
				self:add('-activate', target, 'ability = Wonder Guard')
				return null
			end
		end,
		id = "wonderguard",
		name = "Wonder Guard",
		rating = 5,
		num = 25
	},
	['wonderskin'] = {
		onModifyAccuracyPriority = 10,
		onModifyAccuracy = function(accuracy, target, source, move)
			if move.category == 'Status' and type(move.accuracy) == 'number' then
				self:debug('Wonder Skin - setting accuracy to 50')
				return 50
			end
		end,
		id = "wonderskin",
		name = "Wonder Skin",
		rating = 2,
		num = 147
	},
	['zenmode'] = {
		onSwitchIn = function(pokemon)
			pokemon:addVolatile('zenmode')
		end,
		effect = {
			onStart = function(pokemon)
				if pokemon.template.speciesid == 'darmanitangalar' then
					if pokemon:formeChange('Darmanitan-ZenGalar') and pokemon.volatiles['zenmode'] then
						self:add('-formechange', pokemon, 'Darmanitan-ZenGalar', '[from] ability: Zen Mode')
					else
						return false
					end
				else
					if pokemon:formeChange('Darmanitan-Zen') and pokemon.volatiles['zenmode'] then
						self:add('-formechange', pokemon, 'Darmanitan-Zen', '[from] ability: Zen Mode')
					else
						return false
					end	
				end
			end,
			onEnd = function(pokemon)
				if pokemon.template.speciesid == 'darmanitanzengalar' then
					if pokemon:formeChange('Darmanitan-Galar') and not pokemon.volatiles['zenmode'] then
						self:add('-formechange', pokemon, 'Darmanitan-Galar', '[from] ability: Zen Mode')
					else
						return false
					end
				else
					if pokemon:formeChange('Darmanitan') and not pokemon.volatiles['zenmode'] then
						self:add('-formechange', pokemon, 'Darmanitan', '[from] ability: Zen Mode')
					else
						return false
					end	
				end
			end,
		},
		id = "zenmode",
		name = "Zen Mode",
		rating = 3,
		num = 161
	},

	['libero'] = {
		onBeforeMovePriority = 14,
		onBeforeMove = function(source, target, move)
			local type = move.type
			if type and type ~= '???' and table.concat(source:getTypes(), '') ~= type then
				if not source:setType(type) then return end
				self:add('-start', source, 'typechange', type, '[from] Libero')
			end
		end,
		id = "libero",
		name = "Libero",
		rating = 4.5,
		num = 236
	},

	['steamengine'] = {
		onAfterDamage = function(damage, target, source, effect) 
			if (effect and effect.type == 'Water' or effect.type == 'Fire') then
				self:boost({spe = 6})
			end
		end,
		id = "steamengine",
		name = "Steam Engine",
		rating = 3,
		num = 243
	},
	['punkrock']= {
		onModifyBasePowerPriority= 8,
		onModifyBasePower=function(basePower, attacker, defender, move) 
			if (move.flags['sound']) then
				self:debug('Punk Rock boost')
				return self:chainModify(0x14CD, 0x1000)
			end
		end,
		onSourceModifyDamage=function(damage, source, target, move) 
			if (move.flags['sound']) then
				self:debug('Punk Rock weaken')
				return self:chainModify(0.5)
			end
		end,
		id = 'punkrock',
		name = 'Punk Rock',
		rating = 3.5,
		num = 244,
	},	
	['sandspit'] = {
		onDamagingHit = function(damage, target, source, move)
			if (self:getWeather().id ~= 'sandstorm') then
				self:setWeather('sandstorm')
			end
		end,
		name = "Sand Spit",
		rating = 2,
		num = 245,
		id = 'sandspit'
	},
	['corrosion'] = {
		onModifyMovePriority = -5,
		onModifyMove = function(move)
			if not move.ignoreImmunity then move.ignoreImmunity = {} end
			if move.ignoreImmunity ~= true then
				move.ignoreImmunity['Steel'] = true
				move.ignoreImmunity['Poison'] = true
			end
		end,
		id = "corrosion",
		name = "Corrosion",
		rating = 2,
		num = 212
	},	

	['watercompaction'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Water'  then
				self:boost({def = 2})
			end
		end,
		id = "watercompaction",
		name = "Water Compaction",
		rating = 1.5,
		num = 195
	},

	['triage'] = {
		onModifyPriority = function(priority, pokemon, target, move)
			if move.flags and move.flags ['heal']
			then return priority + 3
			end
		end,
		id = "triage",
		name = "Triage",
		rating = 3.5,
		num = 205
	},	

	['glacialabsorb'] = { --CUSTOM ABILITY CHANGE ID IF NEEDED
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Ice' then
				if not self:boost({spa = 1}) then
					self:add('-immune', target, '[msg]')
				end
				return null
			end
		end,
		onAnyRedirectTargetPriority = 1,
		onAnyRedirectTarget = function(target, source, source2, move)
			if move.type ~= 'Ice' or ({firepledge=true, grasspledge=true, waterpledge=true})[move.id] then return end
			if self:validTarget(self.effectData.target, source, move.target) then
				return self.effectData.target
			end
		end,
		id = "glacialabsorb",
		name = "Glacial Absorb",
		rating = 3.5,
		num = 231
	},		

	['battery'] = {
		onModifySpAPriority = 5,
		onModifySpA = function(spa, pokemon)
			for _, ally in pairs(pokemon.side.active) do
				return self:chainModify(1.3)
			end
		end,
		id = "battery",
		name = "Battery",
		rating = 2,
		num = 217
	},	

	['queenlymajesty'] = {
		onFoeTryMove = function(target, source, move)
			local targetAllExceptions = {'perishsong', 'flowershield', 'rototiller'}
			if (move.target == 'foeSide' or (move.target == 'all' and not targetAllExceptions:find(move.id))) then
				return
			end
			local dazzlingHolder = self.effectData.target
			if ((source.side == dazzlingHolder.side or move.target == 'all') and move.priority > 0.1) then
				self:attrLastMove('[still]')
				self:add('cant', dazzlingHolder, 'ability: Queenly Majesty', move, '[of] '..target)
				return false
			end
		end,
		id = 'queenlymajesty',
		name = 'Queenly Majesty',
		rating = 2.5,
		num = 214,
	},
	['fluffy'] = {
		onSourceModifyDamage= function(damage,source,target,move)
			local mod = 1
			if move.type == "Fire" then mod = mod * 2
				if move.flags["contact"]then mod = mod / 2		
					return self:chainModify (mod)	
				end	
			end				
		end,
		id = "fluffy",
		name = "Fluffy",
		rating = 3.5,
		num = 218
	},		

	['berserk'] = {
		onDamage = function(damage, target, source, effect)
			if effect.effectType == 'Move' and not effect.multihit and (not effect.negateSecondary and not (effect.hasSheetForce and source.hasAbility('sheerforce'))) then --Check if thats right
				self.effectData.checkedBerserk = false
			else
				self.effectData.checkedBerserk = true
			end
		end,
		onTryEatItem = function(item, pokemon)
			local healingItems = {'aguavberry', 'enigmaberry', 'figyberry', 'iapapaberry', 'magoberry', 'sitrusberry', 'wikiberry', 'oranberry', 'berryjuice'}
			if healingItems[item.id] then
				return self.effectData.checkedBerserk
			end
			return true
		end,
		onAfterSecondary = function(target, source, move)
			self.effectData.checkedBerserk = true
			if not (source or source == target or target.hp or move.totalDamage) then return end
			local lastAttackedBy = target:getLastAttackedBy() --Check if it exists
			if not lastAttackedBy then return end
			local damage = move.multihit or move.totalDamage or lastAttackedBy.damage
			if (target.hp <= target.maxhp/2 and target.hp + damage > target.maxhp/2) then
				self:boost({spa=1})
			end
		end,
		id = 'berserk',
		name = 'Berserk',
		rating = 2,
		num = 201,
	},
	['wimpout'] = {
		onAfterMoveSecondary = function(target, source, move)
			if not target.side:canSwitch(target.position) or target.forceSwitchFlag then return end
			if source and source ~= target and target.hp <= target.maxhp/2  and move.category ~= 'Status' then
				self:add('-activate', target, 'ability: Wimp Out')
				target.switchFlag = true
				source.switchFlag = false
			end
		end,
		id = "wimpout",
		name = "wimpout",
		rating = 2,
		num = 193	
	},
	['emergencyexit'] = {
		onAfterMoveSecondary = function(target, source, move)
			if not target.side:canSwitch(target.position) or target.forceSwitchFlag then return end
			if source and source ~= target and target.hp <= target.maxhp/2  and move.category ~= 'Status' then
				self:add('-activate', target, 'ability: Emergency Exit')
				target.switchFlag = true
				source.switchFlag = false
			end
		end,
		id = "emergencyexit",
		name = "Emergency Exit",
		rating = 1,
		num = 194	
	},
	['disguise'] = {
		onDamagePriority = 1,
		onDamage = function(damage, target, source, effect)
			if effect and effect.effectType == 'Move' and target.template.species == 'Mimikyu' and not self.effectData.busted and target:formeChange('Mimikyu-Busted') then
				self.effectData.busted = true
				self:add('-activate', target, 'ability: Disguise')
				self:add('-formechange', target, 'Mimikyu-Busted')
				return 0
			end
		end,
		onFaint = function(pokemon)
			if pokemon.template.species == 'Mimikyu' and self.effectData.busted and pokemon:formeChange('Mimikyu') then
				self.effectData.busted = false
				self:add('-formechange', pokemon, 'Mimikyu', '[silent]')
			end
		end,

		name = 'Disguise',
		num = 209,
		id = 'disguise'
	},
	['stakeout'] = { --Should Be FIXED!
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, attacker, defender, move)
			if defender.activeTurns == 1 then
				self:debug ("Stakeout Boost")
				return self:chainModify(2)				
			end
		end,	
		onModifySpAPriority = 5,
		onModifySpA = function(atk, attacker, defender, move)
			if defender.activeTurns == 1 then
				self:debug ("Stakeout Boost")
				return self:chainModify(2)
			end
		end,	
		id = "stakeout",
		name = "Stakeout",
		rating = 4.5,
		num = 198
	},		

	--[[
Add AlliesAndSelf()
]]


	['ripen'] = {
		onResidualOrder = 26,
		onResidualSubOrder = 1,
		onResidual = function(pokemon)
			if self:isWeather({'sunnyday', 'desolateland'}) or math.random(2) == 1 then
				if pokemon.hp and Not(pokemon.item) and self:getItem(pokemon.lastItem).isBerry then
					pokemon:setItem(pokemon.lastItem)
					self:add('-item', pokemon, pokemon:getItem(), '[from] ability = Ripen')
				end
			end
		end,
		id = "ripen",
		name = "Ripen",
		rating = 2,
		num = 247
	},

	['merciless'] = {
		onModifyCritRatio = function(critRatio,source,target)
			if target.status == "psn" or "tox" then
				return 5
			end
		end,
		id = "merciless",
		name = "Merciless",
		rating = 1.5,
		num = 196
	},			

	['stamina'] = {
		onHit = function(target, source, move)
			self:boost({def = 1})	
		end,
		id = "stamina",
		name = "Stamina",
		rating = 3.5,
		num = 192
	},				
	['shieldsdown'] = {
		onBeforeSwitchIn = function(pokemon)
			if (pokemon.baseTemplate.species ~= 'Minior' or pokemon.transformed) then return end
			if (pokemon.hp > pokemon.maxhp / 2) then
				if pokemon.template.speciesid ~= 'miniormeteor' then
					pokemon:formeChange('Minior-Meteor')
					self:add('-formechange', pokemon, 'Minior-Meteor', '[silent]')
					local template = self:getTemplate('Minior-Meteor')
					pokemon.baseStatOverride = template.baseStats
					pokemon.iconOverride = 951
				end
			else
				if (pokemon.template.speciesid == 'miniormeteor') then
					pokemon:formeChange(pokemon.baseTemplate.species)
					self:add('-formechange', pokemon, pokemon.baseTemplate.species, '[silent]')
				end
			end
		end,
		onResidualOrder = 27,
		onResidual = function(pokemon)
			if (pokemon.baseTemplate.species ~= 'Minior' or pokemon.transformed) then return end
			if (pokemon.hp > pokemon.maxhp / 2) then
				if pokemon.template.speciesid ~= 'miniormeteor' then
					pokemon:formeChange('Minior-Meteor')
					self:add('-formechange', pokemon, 'Minior-Meteor', '[silent]')
					local template = self:getTemplate('Minior-Meteor')
					pokemon.baseStatOverride = template.baseStats
				end
			else
				if pokemon.template.speciesid == 'miniormeteor' then
					pokemon:formeChange(pokemon.baseTemplate.species)
					self:add('-formechange', pokemon, pokemon.baseTemplate.species, '[silent]')
					self:add('-ability', pokemon, 'Shields Down')
					local template = self:getTemplate('Minior-Red')
					pokemon.baseStatOverride = template.baseStats
				end
			end
		end,
		onSetStatus = function(status, target, source, effect)
			if target.template.speciesid ~= 'miniormeteor' or target.transformed then return end
			if effect.status then
				self:add('-immune', target, '[from] ability: Shields Down')
			end
			return false
		end,
		onTryAddVolatile = function(status, target)
			if target.template.speciesid ~= 'miniormeteor' or target.transformed then return end 
			if status.id ~= 'yawn' then return end
			self:add('-immune', target, '[from] ability: Shields Down')
			return
		end,
		name = 'Shields Down',
		id = 'shieldsdown', 
		rating = 3,
		num = 197,
	},

	['quickdraw'] = {
		onFractionalPriorityPriority = 1,
		onFractionalPriority = function(priority, pokemon, target, move)
			if (move.category == 'Status' and self:randomChance(3, 10)) then
				self:add('-activate', pokemon, 'ability: Quick Draw')
				return 0.1
			end
		end,
		id = "quickdraw",
		name = "Quick Draw",
		rating = 2.5,
		num = 259
	},

	['electricsurge'] = {
		onStart = function(source)
			self:setTerrain('electricterrain')
		end,
		id = "electricsurge",
		name = "Electric Surge",
		rating = 4,
		num = 226
	},
	['psychicsurge'] = {
		onStart = function(source)
			self:setTerrain('psychicterrain')
		end,
		id = "psychicsurge",
		name = "Psychic Surge",
		rating = 4,
		num = 227
	},
	['mistysurge'] = {
		onStart = function(source)
			self:setTerrain('mistyterrain')
		end,
		id = "mistysurge",
		name = "Misty Surge",
		rating = 4,
		num = 228
	},
	['grassysurge'] = {
		onStart = function(source)
			self:setTerrain('grassyterrain')
		end,
		id = "grassysurge",
		name = "Grassy Surge",
		rating = 4,
		num = 229
	},
	['fullmetalbody'] = {
		onBoost = function(boost, target, source, effect)
			if source and target == source then return end
			local showMsg = false
			for i, b in pairs(boost) do
				if b < 0 then
					boost[i] = nil
					showMsg = true
				end
			end
			if showMsg and not effect.secondaries then
				self:add("-fail", target, "unboost", "[from] ability = Full Metal Body", "[of] " .. target)
			end
		end,
		id = "fullmetalbody",
		name = "Full Metal Body",
		rating = 2,
		num = 230
	},
	['shadowshield'] = {
		onSourceModifyDamage = function(damage, source, target, move)
			if target.hp >= target.maxhp then
				self:debug('Shadow Shield weaken')
				return self:chainModify(0.5)
			end
		end,
		id = "shadowshield",
		name = "Shadow Shield",
		rating = 4,
		num = 231
	},
	['icescales'] = {
		onSourceModifyDamage = function(damage, source, target, move)
			if move.category == "Special" then
				self:debug ("Half damage taken due to Ice Scales")
				return self:chainModify(0.5)
			end
		end,
		id = "icescales",
		name = "Ice Scales",
		rating = 4,
		num = 246
	},
	['iceface'] = {
		onStart = function(pokemon) 
			if (self:isWeather('hail') and pokemon.species.id == 'eiscuenoice' and not pokemon.transformed) then
				self:add('-activate', pokemon, 'ability: Ice Face')
				self.effectData.busted = false
				self:formeChange('Eiscue', self.effect, true)
			end
		end,
		onDamagePriority = 1,
		onDamage = function(damage, target, source, effect)
			if (effect and effect.effectType == 'Move' and effect.category == 'Physical' and target.species.id == 'eiscue' and not target.transformed) then
				self:add('-activate', target, 'ability: Ice Face')
				self.effectData.busted = true
				return 0
			end
		end,
		onCriticalHit = function(target, type, move)
			if not (target) then return end
			if (move.category ~= 'Physical' or target.species.id ~= 'eiscue' or target.transformed) then return end
			if (target.volatiles['substitute'] and not (move.flags['authentic'] or  move.infiltrates)) then return end
			if not (target:runImmunity(move.type)) then return end
			return false
		end,
		onEffectiveness = function(typeMod, target, type, move)
			if not (target) then return end
			if (move.category ~= 'Physical' or target.species.id ~= 'eiscue' or target.transformed) then return end
			if (target.volatiles['substitute'] and not (move.flags['authentic'] or move.infiltrates)) then return end
			if not (target.runImmunity(move.type)) then return end
			return 0
		end,
		onUpdate = function(pokemon) 
			if (pokemon.species.id == 'eiscue' and self.effectData.busted) then
				pokemon:formeChange('Eiscue-Noice', self.effect, true)
			end
		end,
		onAnyWeatherStart = function()
			local pokemon = self.effectData.target
			if not (pokemon.hp) then return end
			if (self:isWeather('hail') and pokemon.species.id == 'eiscuenoice' and not pokemon.transformed) then
				self:add('-activate', pokemon, 'ability: Ice Face')
				self.effectData.busted = false
				pokemon:formeChange('Eiscue', self.effect, true)
			end
		end,
		name = "Ice Face",
		rating = 3,
		num = 248,
		id = 'iceface'
	},
	powerspot = {
		onBasePowerPriority = 22,
		onBasePower = function(basePower, attacker, defender, move)
			if (attacker == self.effectData.target) then
				self:debug('Power Spot boost')
				return self:chainModify(5325, 4096)
			end
		end,
		name = "Power Spot",
		rating = 1,
		num = 249,
		id = 'powerspot'
	},
	--[[	mimicry: {
			onStart(pokemon) {
				if (this.field.terrain) {
					pokemon.addVolatile('mimicry')
					} else {
		const types = pokemon.baseSpecies.types
		if (pokemon.getTypes().join() === types.join() || !pokemon.setType(types)) return
			this.add('-start', pokemon, 'typechange', types.join('/'), '[from] ability: Mimicry')
			this.hint("Transform Mimicry changes you to your original un-transformed types.")
			}
		},
		onAnyTerrainStart() {
		const pokemon = this.effectData.target
		delete pokemon.volatiles['mimicry']
		pokemon.addVolatile('mimicry')
	},
	onEnd(pokemon) {
		delete pokemon.volatiles['mimicry']
	},
	condition: {
		onStart(pokemon) {
			let newType
			switch (this.field.terrain) {
				case 'electricterrain':
				newType = 'Electric'
				break
				case 'grassyterrain':
				newType = 'Grass'
				break
				case 'mistyterrain':
				newType = 'Fairy'
				break
				case 'psychicterrain':
				newType = 'Psychic'
				break
			}
			if (!newType || pokemon.getTypes().join() === newType || !pokemon.setType(newType)) return
				this.add('-start', pokemon, 'typechange', newType, '[from] ability: Mimicry')
		},
		onUpdate(pokemon) {
			if (!this.field.terrain) {
				const types = pokemon.species.types
				if (pokemon.getTypes().join() === types.join() || !pokemon.setType(types)) return
					this.add('-activate', pokemon, 'ability: Mimicry')
					this.add('-end', pokemon, 'typechange', '[silent]')
					pokemon.removeVolatile('mimicry')
					}
		},
	},
	name: "Mimicry",
	rating: 0.5,
	num: 250,
	},]]
	--[[
	screencleaner: {
		onStart(pokemon) {
			let activated = false
			for (const sideCondition of ['reflect', 'lightscreen', 'auroraveil']) {
				if (pokemon.side.getSideCondition(sideCondition)) {
					if (!activated) {
						this.add('-activate', pokemon, 'ability: Screen Cleaner')
						activated = true
					}
					pokemon.side.removeSideCondition(sideCondition)
				}
				if (pokemon.side.foe.getSideCondition(sideCondition)) {
					if (!activated) {
						this.add('-activate', pokemon, 'ability: Screen Cleaner')
						activated = true
					}
					pokemon.side.foe.removeSideCondition(sideCondition)
				}
			}
		},
		name: "Screen Cleaner",
		rating: 2,
		num: 251,
	},
	]]
	['steelyspirit'] = {
		onStart = function(pokemon,source)
			local targets = {}
			local activated = false
			for _, side in pairs(self.sides) do
				for _, pokemon in pairs(side.active) do
					if pokemon ~= null and not pokemon.fainted and pokemon:hasType('Steel') then

						table.insert(targets, pokemon)
					end
				end
			end
			if #targets == 0 then return false end -- No targets; move fails
			for _, target in pairs(targets) do
				self:boost({atk = 1}, target, source, self:getMove('Steely Spirit'))
			end
		end,
		id = "steelyspirit",
		name = "Steely Spirit",
		rating = 3.5,
		num = 252
	},
	['screencleaner'] = {
		onStart = function(pokemon)
			if not Not(pokemon:runImmunity('Fighting')) then
				pokemon.side:removeSideCondition('reflect')
				pokemon.side:removeSideCondition('lightscreen')
				pokemon.side:removeSideCondition('auroraveil')
			end
		end,
		id = "screencleaner",
		name = "Screen Cleaner",
		rating = 2,
		num = 251
	},
	['mimicry'] = {
		onStart = function(target)
			local newType = 'Normal'
			if self:isTerrain('electricterrain') then
				newType = 'Electric'
			elseif self:isTerrain('grassyterrain') then
				newType = 'Grass'
			elseif self:isTerrain('mistyterrain') then
				newType = 'Fairy'
			end

			if Not(target:setType(newType)) then return false end
			self:add('-start', target, 'typechange', newType)
		end,
		id = "mimicry",
		name = "Mimicry",
		rating = 0.5,
		num = 250

	},
	['perishbody'] = {
		onDamagingHit = function(self, damage, target, source, move)
			if not self:checkMoveMakesContact(move, source, target) then
				return
			end
			local announced = false
			for i, pokemon in ipairs({target, source}) do
				do
					if not pokemon.volatiles.perishsong then
						if not announced then
							self:add("-ability", target, "Perish Body")
							announced = true
							pokemon:addVolatile("perishsong")
						end
					end
				end
			end
		end,
		id = "perishbody",
		name = "Perish Body",
		rating = 1,
		num = 253
	},
	['wanderingspirit'] = {
		onDamagingHit = function(damage, target, source, move)
			local additionalBannedAbilities = {'hungerswitch', 'illusion', 'neutralizinggas', 'wonderguard'}
			if (source:getAbility().isPermanent or additionalBannedAbilities:find(source.ability) or target.volatiles['dynamax']) then return end
			if (move.flags['contact']) then
				local sourceAbility = source:setAbility('wanderingspirit', target)
				if not (sourceAbility) then return end
				if (target.side == source.side) then
					self:add('-activate', target, 'Skill Swap', '', '', '[of] '..source)
				else
					self:add('-activate', target, 'ability: Wandering Spirit', self:getAbility(sourceAbility).name, 'Wandering Spirit', '[of] '..source)
				end
				target:setAbility(sourceAbility)
			end
		end,

		id = "wanderingspirit",
		name = "Wandering Spirit",
		rating = 2.5,
		num = 254
	},
	['gorillatactics'] = {		
		OnStart = function (pokemon)
			if pokemon.activeTurns == 0 then
				return false
			end
		end,
		onModifyAtk = function(atk)
			return self:chainModify(1.5)
		end,
		onDisableMove = function(pokemon)       
			for _, move in pairs(pokemon.moveset) do
				if not pokemon.lastMove then return end
				if move.id ~= pokemon.lastMove and pokemon.activeTurns > 0 then
					pokemon:disableMove(move.id)
				end
			end
		end,
		id = "gorillatactics",
		name = "Gorilla Tactics",
		rating = 4.5,
		num = 255
	},	
	['neutralizinggas'] = {
		onPreStart = function(self, pokemon)
			if pokemon.transformed then
				return
			end
			self:add("-ability", pokemon, "Neutralizing Gas")
			pokemon.abilityState.ending = false
			for i, target in pairs(self:getAllActive()) do
				if target.illusion then
					self:singleEvent(
						"End",
						self.dex.abilities:get("Illusion"),
						target.abilityState,
						target,
						pokemon,
						"neutralizinggas"
					)
				end
				if target.volatiles.slowstart then
					target.volatiles.slowstart = nil
					self:add("-end", target, "Slow Start", "[silent]")
				end
			end
		end,
		onEnd = function(self, source)
			if source.transformed then
				return
			end
			for i, pokemon in pairs(self:getAllActive()) do
				if pokemon ~= source and pokemon:hasAbility("Neutralizing Gas") then
					return
				end
			end
			self:add("-end", source, "ability: Neutralizing Gas")
			if source.abilityState.ending then
				return
			end
			source.abilityState.ending = true
			local sortedActive = self:getAllActive()
			self:speedSort(sortedActive)
			for i, pokemon in pairs(sortedActive) do
				do
					if pokemon ~= source then
						self:singleEvent(
							"Start",
							pokemon:getAbility(),
							pokemon.abilityState,
							pokemon
						)
					end
				end
			end
		end,
		id = "neutralizinggas",
		name = "Neutralizing Gas",
		rating = 4,
		num = 256
	},
	['pastelveil'] = {
		onStart = function(pokemon)
			for _, ally in pairs(pokemon.side.active) do
				if ally.status['psn'] or ally.status['tox'] then
					self:add('-activate', pokemon, 'ability: Pastel Veil')
					ally:cureStatus()
				end
			end
		end,
		onUpdate = function(pokemon)
			if pokemon.status['psn'] or pokemon.status['tox'] then
				self:add('-activate', pokemon, 'ability: Pastel Veil')
				pokemon:cureStatus()
			end
		end,
		onAllySwitchIn = function(pokemon)
			if pokemon.status['psn'] or pokemon.status['tox'] then
				self:add('-activate', self.effectData.target, 'ability: Pastel Veil')
				pokemon:cureStatus()
			end
		end,
		onSetStatus = function(status, target, source, effect)
			if not (status.id == 'psn' or status.id == 'tox') then return end
			return false
		end,
		onAllySetStatus = function(status, target, source, effect)
			if not (status.id == 'psn' or status.id == 'tox') then return end
			return false
		end,
		name = 'Pastel Veil',
		id = 'pastelveil',
		num = 257,
	},
	['hungerswitch'] = {
		onBeforeMovePriority = 11,
		onBeforeMove = function(pokemon, target, move)
			if pokemon.template.species ~= 'Morpeko' then return end
			if move.category == 'Physical' then
				if Not(pokemon.template.forme) and pokemon:formeChange('Morpeko-Hangry') then
					self:add('-formechange', pokemon, 'Morpeko-Hangry')
				end
			elseif move.id == 'aurawheel' then
				if pokemon.template.forme == 'Hangry' and pokemon:formeChange('Morpeko') then
					self:add('-formechange', pokemon, 'Morpeko')
				end
			end
		end,
		id = "hungerswitch",
		name = "Hunger Switch",
		rating = 1,
		num = 258
	},
	['unseenfist'] = {
		flags = {contact = true, protect = true, mirror = true},
		onTryHit = function(pokemon)
			if not Not(pokemon:runImmunity('Fighting')) then
				pokemon.side:removeSideCondition('protect')
				pokemon.side:removeSideCondition('detect')
			end
		end,
		id = "unseenfist",
		name = "Unseen Fist",
		rating = 2,
		num = 260
	},
	['curiousmedicine'] = {
		onStart = function(pokemon)
			for _, ally in pairs(pokemon.side.active) do
				if (ally ~= pokemon) then
					ally:clearBoosts()
					self:add('-clearboost', ally, '[from] ability: Curious Medicine', '[of] '..pokemon)
				end
			end
		end,
		name = "Curious Medicine",
		id = 'curiousmedicine',
		rating = 0,
		num = 261,
	},
	['transistor'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, attacker, defender, move)
			if (move.type == 'Electric') then
				return self:chainModify(1.5)
			end
		end,
		onModifySpAPriority = 5,
		onModifySpA = function(atk, attacker, defender, move) 
			if (move.type == 'Electric') then
				return self:chainModify(1.5)
			end
		end,
		name = "Transistor",
		id = 'transistor',
		rating = 3.5,
		num = 262,
	},
	['dragonsmaw'] = {
		onBasePower = function(basePower, attacker, defender, move)
			if move.type == 'Dragon' then
				self:debug('Dragon\'s Maw boost')
				return self:chainModify(1.5)
			end
		end,
		id = "dragonsmaw",
		name = "Dragon's Maw",
		rating = 3.5,
		num = 263
	},
	['chillingneigh'] = {
		onSourceAfterFaint = function(length, target, source, effect)
			if (effect and effect.effectType == 'Move') then
				self:boost({atk = length}, source)
			end
		end,
		name = "Chilling Neigh",
		id = 'chillingneigh',
		rating = 3,
		num =  264,
	},
	['grimneigh'] = {
		onSourceAfterFaint = function(length, target, source, effect)
			if (effect and effect.effectType == 'Move') then
				self:boost({spa = length}, source)
			end
		end,
		name = "Grim Neigh",
		id = 'grimneigh',
		rating = 3,
		num = 265,
	},
	asone = {
		onBeforeStart = function(pokemon)
			self:add('-ability', pokemon, 'As One')
			self:add('-ability', pokemon, 'Unnerve', pokemon.side.foe)
		end,
		onFoeTryEatItem = false,
		onSourceAfterFaint = function(length, target, source, effect)
			if (effect and effect.effectType == 'Move') then
				if source.template.forme == 'shadowrider' then
					self:boost({atk = length}, source, source, self:getAbility('grimneigh'))

				else
					self:boost({atk = length}, source, source, self:getAbility('chillingneigh'))
				end
			end
		end,
		name = "As One",
		id = 'asone',
		rating = 3.5,
		num = 266,
	},
	['waterbubble'] = {		
		onSourceModifyAtkPriority = 5,
		onSourceModifyAtk = function(atk, attacker, defender, move)
			if move.type == 'Fire' then
				self:debug('Water Bubble weaken')
				return self:chainModify(0.5)
			end
		end,
		onSourceModifySpAPriority = 5,
		onSourceModifySpA = function(atk, attacker, defender, move)
			if move.type == 'Fire' then
				self:debug('Water Bubble weaken')
				return self:chainModify(0.5)
			end
		end,
		onModifyAtk = function(atk, attacker, defender, move)
			if move.type == 'Water'then
				self:debug('Water Bubble boost')
				return self:chainModify(2)
			end
		end,
		onModifySpA = function(atk, attacker, defender, move)
			if move.type == 'Water'then
				self:debug('Water Bubble boost')
				return self:chainModify(2)
			end
		end,
		onUpdate = function(pokemon)
			if pokemon.status == 'brn' then
				pokemon:cureStatus()
			end
		end,
		onSetStatus = function(status, target, source, effect)
			if status.id == 'brn' then return false				
			end
		end,
		id = "waterbubble",
		name = "Water Bubble",
		rating = 4.5,
		num = 199
	},		

	['northpole'] = {
		onTryHit = function(target, source, move)
			if target ~= source and move.type == 'Ice' then
				if not self:boost({spa = 1}) then
					self:add('-immune', target, '[msg]')
				end
				return null
			end
		end,
		onAnyRedirectTargetPriority = 1,
		onAnyRedirectTarget = function(target, source, source2, move)
			if move.type ~= 'Ice' or ({firepledge=true, grasspledge=true, waterpledge=true})[move.id] then return end
			if self:validTarget(self.effectData.target, source, move.target) then
				return self.effectData.target
			end
		end,
		id = "northpole",
		name = "North Pole",
		rating = 3.5,
		num = 960
	},
	['angershell'] = {
		onDamage = function(damage, target, source, effect)
			if effect and effect.effectType == 'Move' then
				self.effect.Multihit = true
				if effect.negateSecondary and (effect.hasSheerForce and source.hasAbility('sheerforce')) then
					self.target.abilityState.checkedAngerShell = false
				else
					self.abilityState.checkedAngerShell = true

				end

			end

		end,
		onTryEatItem = function(item,pokemon)
			local healingItems = {'aguavberry', 'enigmaberry', 'figyberry', 'iapapaberry', 'magoberry', 'sitrusberry', 'wikiberry', 'oranberry', 'berryjuice',}
			if healingItems.getItem(item.id) then
				return pokemon.abilityState.checkedAngerShell            
			end
			return true

		end,
		onAfterMoveSecondary = function(target,source,move)
			target.abiliyState.checkedAngerShell = true
			if  (source or source == target or target.hp or move.totalDamage) then return end
			local lastAttackedBy = target.getLastAttackedBy()
			if (lastAttackedBy) then return end
			local damage = move.multihit or move.totalDamage and lastAttackedBy.damage
			if (target.hp  <= target.maxhp /2 and target.hp + damage > target.maxhp /  2 ) then
				self:boost({atk = 1, spa = 1, spe = 1 , def = -1, spd = -1})
			end
		end,
		id = "angershell",
		name = "Anger Shell",
		rating = 4,
		num = 271,
	},
	['beadsofruin'] = {
		onStart =  function(pokemon)
			if (self.suppressingAbility(pokemon)) then return end
			self:add('-ability', pokemon, 'Beads of Ruin');

		end,
		onAnyModifySpD = function(spd,target,source,move)
			local abilityHolder = self.effectState.target
			if (abilityHolder == target) then return end
			if (move.ruinedSpD == abilityHolder and move.ruinedSpD == target) then return end
			self:debug('Bead of Ruin SpD drop');
			return self:chainModify(0.75);
		end,
		id = "beadsofruin",
		name = "Beads of Ruin",
		rating = 4.5,
		num = 284,
	},
	['armortail'] = {
		onFoeTryMove = function(target,source,move)
			local targetAllExceptions = {'perishsong', 'flowershield', 'rototiller'};
			if (move.target == 'foeSide' or move.target == 'all' and targetAllExceptions.getMove(move.id)) then
				return
			end
			local armorTailHolder = self.effectState.target
			if ((source.isAlly(armorTailHolder) or move.target == 'all' and move.priority > 0.1)) then
				self:attrLastMove('[still]')
				self:add('cant', armorTailHolder, 'ability  = Armor Tail', move, '[of]' + target)
				return false
			end
		end,
		id = "armortail",
		name = "Armor Tail",
		rating = 2.5,
		num = 296,
	},
	['commander'] = {
		onUpdate = function(pokemon)
			local ally = pokemon.allies()[0]
			if (ally or pokemon.baseSpecies == 'Tatsugiri' or ally.baseSpecies == 'Dondozo') then
				if (pokemon.getVolatile('commanding')) then
					pokemon.removeVolatile('commanding')
					return 
				end
				if (pokemon.getVolatile('commanding')) then
					if (ally.getVolatile('commanded')) then return end
					self.queue.cancelAction(pokemon)
					pokemon.addVolatile('commanding')
					ally.addVolatile('commanded', pokemon)
				else
					if (ally.fainted) then
						pokemon.removeVolatile('commanding')
						return true
					end
				end
			end
		end,
		id = "commander",
		name = "Commander",
		rating = 0,
		num = 279,
	},
	['costar'] = {
		onStart = function(pokemon, boost)
			local ally = pokemon.allies()[0]
			if (ally) then return end
			for i, b in pairs(boost) do
				local boosts = ally.boosts
				pokemon.boosts[i] = ally.boosts[i]	
			end

			local volatilesToCopy = {'focusenergy', 'gmaxchistrike', 'laserfocus'}
			local volatile  = true
			if (ally.volatiles[volatile]) then
				pokemon.addVolatile(volatile)
				if (volatile == 'gmaxchistrike') then
					pokemon.volatiles[volatile].layers = ally.volatiles[volatile].layers
				else
					pokemon.removeVolatile(volatile)
				end
			end
			self:add('-copyboost', pokemon,ally, '[from] ability  = Costar')
		end,
		id = "costar",
		name = "Costar",
		rating = 0,
		num = 294
	},
	['zerotohero'] = {
		onSwitchOut = function(pokemon)
			if pokemon.template.species == 'Palafin' and not pokemon.side.heroActivated and pokemon.hp > 0 and not pokemon.transformed and pokemon.side.pokemonLeft > 0 then
				self:add('-activate', pokemon, 'ability: Zero to Hero')
				local template = self:getTemplate('Palafin-Hero')
				pokemon:formeChange(template)
				pokemon.baseTemplate = template
				pokemon.details = template.species .. ', L' .. pokemon.level .. (pokemon.gender == '' and '' or ', ') .. pokemon.gender .. (pokemon.set.shiny and ', shiny' or '')
				self:add('detailschange', pokemon, pokemon.details, '[zeroToHero]', '[icon] ' .. (template.icon or 0))
				local shinyPrefix = pokemon.shiny and '_SHINY' or ''
				self:setupDataForTransferToPlayers('Sprite', shinyPrefix .. '_FRONT/Palafin-Hero')
				self:setupDataForTransferToPlayers('Sprite', shinyPrefix .. '_BACK/Palafin-Hero')

				pokemon.iconOverride = template.icon - 1
				-- is there a better way to access this?
				pokemon.frontSpriteOverride = require(game:GetService('ServerStorage').Data.GifData)[shinyPrefix .. '_FRONT']['Palafin-Hero']
				pokemon.baseStatOverride = template.baseStats

				pokemon.side.heroActivated = true
			end
		end,
		id = "zerotohero",
		name = "Zero to Hero",
		rating = 5,
		num = 278,
	},
	['guarddog'] = {
		onDragOut = function(pokemon)
			self:add('-activate', pokemon, 'ability: Guard Dog')
			return nil
		end,

		onBoost = function(boost, target, source, effect)
			if effect.name == 'Intimidate' then
				boost.atk = nil
				self:boost({atk = 1}, target, target, nil, false, true)
			end
		end,
		id = "guarddog",
		name = "Guard Dog",
		rating = 2,
		num = 275,
	},
	['windrider'] = {
		onStart = function(pokemon)
			if (pokemon.side.sideConditions['tailwind']) then
				self:boost({atk = 1}, pokemon, pokemon)

			end
		end,
		onTryHit = function(target, source, move)
			if (target == source and move.flags['wind']) then
				self:add('-immune', target, '[from] ability = Wind Rider')

			end
			return null
		end,
		onAllySideConditionStart = function(target,source,sideCondition)
			local pokemon = self.effectState.target
			if (sideCondition.id == 'tailwind') then
				self:boost({atk = 1}, pokemon,pokemon)
			end
		end,
		id = "windrider",
		name = "Wind Rider",
		rating = 3.5,
		num = 274,
	},
	['windpower'] = {
		onDamagingHitOrder = 1,
		onDamagingHit = function(damage, target,source,move) 
			if (move.flags['wind']) then
				target.addVolatile('charge')
			end
		end,
		onAllySideConditionStart = function(target,source, sideCondition)
			local pokemon = self.effectState.target
			if (sideCondition.id == 'tailwind') then
				pokemon.addVolatile('charge')
			end
		end,
		id = "windpower",
		name = "Wind Power",
		rating = 1,
		num = 277,
	},
	['wellbakedbody'] = {
		onTryHit = function(target, source, move)
			if (target ~= source and move.type == 'Fire') then
				if (not self:boost({def = 2})) then
					self:add('-immune', target, '[from] ability = Well-Baked Body')
				end
				return null
			end
		end,
		id = "wellbakedbody",
		name = "Well-Baked Body",
		rating = 3.5,
		num = 273,
	},
	['vesselofruin'] = {
		onStart = function(pokemon)
			if (self.suppressingAbility(pokemon)) then return end
			self:add('-ability', pokemon, 'Vessel of Ruin')
		end,
		onAnyModifySpA = function(spa, source, target, move)
			local abilityHolder = self.effectState.target
			if (abilityHolder == source) then return end
			if (move.ruinedSpA) then
				move.ruinedSpA = abilityHolder 
				if(move.ruinedSpA == abilityHolder) then return end
				self:debug('Vessel of Ruin SpA drop')
				return self:chainModify(0.75)
			end
		end,
		id = "vesselofruin",
		name = "Vessel Of Ruin",
		rating = 4.5,
		num = 284,
	},
	['toxicdebris'] = {
		onDamagingHit = function(damage, target, source,move)
			local side = source.isAlly(target) source.side.foe  = source.side
			local toxicSpikes = side.sideConditions['toxicspikes']
			if (move.category == 'Physical' and (toxicSpikes or toxicSpikes.layers < 2)) then
				self:add('-activate', target, 'ability = Toxic Debris')
			end
		end,
		id = "toxicdebris",
		name = "Toxic Debris",
		rating = 3.5,
		num = 295,

	},
	['eartheater'] = {
		onTryHit = function(target, source, move)
			if (target == source and move.type == 'Ground') then
				if (self:heal(target.baseMaxhp / 4)) then
					self:add('-immune', target, '[from] ability = Earth Eater')
				end
				return null
			end
		end,
		id = "eartheater",
		name = "Earth Eater",
		rating = 3.5,
		num = 297,
	},
	['thermalexchange'] = {
		onAfterDamage = function(damage, target, source, move)
			if (move.type == 'Fire') then
				print('Thermal Exchange Boost')
				self:boost({atk = 1})
			end
		end,
		onUpdate = function(pokemon)
			if pokemon.status == 'brn' then
				pokemon:cureStatus()
			end
		end,
		onImmunity = function(type)
			if type == 'brn' then return false end
		end,
		id = "thermalexchange",
		name = "Thermal Exchange",
		rating = 2.5,
		num = 270,
	},
	['tabletsofruin'] = {
		onStart = function(pokemon)
			if pokemon:suppressingAbility() then return end
			pokemon:add('-ability', pokemon, 'Tablets of Ruin')
		end,
		onAnyModifyAtk = function(atk, source, target, move)
			local abilityHolder = move.effectState.target
			if abilityHolder == source then return end
			if not move.ruinedAtk then move.ruinedAtk = abilityHolder end
			if move.ruinedAtk ~= abilityHolder then return end
			print('Tablets of Ruin Atk drop')
			return self:chainModify(0.75)
		end,
		id = "tabletsofruin",
		name = "Tablets of Ruin",
		rating = 4.5,
		num = 284,
	},
	['supremeoverlord'] = {
		onBasePower = function()
			local totalalive = #self.totalalive
			local party = 6

			local numfainted = math.min(party - totalalive, 5)
			if numfainted > 0 then
				local boost = 1 + (0.1 * numfainted)
				print('boosting power')
				self:chainModify(boost)
			end
		end,

		id = "supremeoverlord",
		name = "Supreme Overlord",
		rating = 3.5,
		num = 293,
	},
	['swordofruin'] = {
		onStart = function(pokemon)
			if pokemon:suppressingAbility() then return end
			pokemon:add('-ability', pokemon, 'Sword of Ruin')
		end,
		onAnyModifyDef = function(def, target, source, move)
			local abilityHolder = move.effectState.target
			if abilityHolder == target then return end
			if not move.ruinedDef then move.ruinedDef = abilityHolder
			elseif not move.ruinedDef:hasAbility('Sword of Ruin') then move.ruinedDef = abilityHolder end
			if move.ruinedDef ~= abilityHolder and move.ruinedDef ~= target then return end
			print('Sword of Ruin Def drop')
			return self:chainModify(0.75)
		end,
		id = "swordofruin",
		name = "Sword of Ruin",
		rating = 4.5,
		num = 285,
	},
	['seedsower'] = {
		onDamagingHit = function(damage, target, source, move)
			self:setTerrain('grassyterrain')
		end,
		id = "seedsower",
		name = "Seed Sower",
		rating = 2.5,
		num = 269,
	},
	['rockypayload'] = {
		onModifyAtkPriority = 5,
		onModifyAtk  = function(atk, attacker, defender, move)
			if (move.type == 'Rock') then
				self:debug('Rocky Payload Boost')
				return self:chainModify(1.5)
			end
		end,
		onModifySpAPriority = 5,
		onModifySpA = function(atk, attacker, defender, move)
			if (move.type == 'Rock') then
				self:debug('Rocky Payload Boost')
				return self:chainModify(1.5)
			end
		end,
		id = "rockypayload",
		name = "Rocky Payload",
		rating = 3.5,
		num = 276,
	},
	['purifyingsalt'] = {
		onSetStatus = function(status, target, source, effect)
			if effect and effect.status then
				target:add('-immune', target, '[from] ability: Purifying Salt')
			end
			return false
		end,
		onTryAddVolatile = function(status, target)
			if status.id == 'yawn' then
				target:add('-immune', target, '[from] ability: Purifying Salt')
				return nil
			end
		end,
		onSourceModifyAtkPriority = 6,
		onSourceModifyAtk = function(atk, attacker, defender, move)
			if move.type == 'Ghost' then
				print('Purifying Salt weaken')
				return self:chainModify(0.5)
			end
		end,
		onSourceModifySpAPriority = 5,
		onSourceModifySpA = function(spa, attacker, defender, move)
			if move.type == 'Ghost' then
				print('Purifying Salt weaken')
				return self:chainModify(0.5)
			end
		end,
		id = "purifyingsalt",
		name = "Purifying Salt",
		rating = 4,
		num = 272
	},
	['quarkdrive'] = {
		onStart = function(pokemon)
			if pokemon.item and pokemon.item == 'boosterenergy' then
				self:boost({spe = 1})
			end
		end,
		onModifySpe = function(spe)
			if (self:isTerrain('electricterrain')) then
				return self:chainModify(1.5)
			end
		end,
		id = "quarkdrive",
		name = "Quark Drive",
		rating = 4,
		num = 296,
	},
	['opportunist'] = {
		onBoost = function(boost, target, source, effect)
			-- Don't activate if the boost source is an ally or already has Opportunist
			if source.side == target.side or effect.id == 'opportunist' then
				return
			end

			local copiedBoost = {}
			for stat, value in pairs(boost) do
				if value > 0 then
					copiedBoost[stat] = (copiedBoost[stat] or 0) + value
				end
			end

			if next(copiedBoost) ~= nil then
				self:add('-ability', target, 'Opportunist')
				self:boost(copiedBoost, target)
				self:debug('Opportunist ability activated!')
			end
		end,
		id = "opportunist",
		name = "Opportunist",
		rating = 3,
		num = 290
	},
	['orichalcumpulse'] = {
		onStart = function(source)
			self:add('-ability', source, 'Orichalcum Pulse', '')
			self:setWeather('desolateland')
			return
		end,
		onEnd = function(pokemon)
			if self.weatherData.source ~= pokemon then return end
			for _, side in pairs(self.sides) do
				for _, target in pairs(side.active) do
					if target ~= null and target ~= pokemon and target.hp > 0 and target:hasAbility('orichalcumpulse') then
						self.weatherData.source = target
						return
					end
				end
			end
			self:clearWeather()
			self.weatherData.source = null
		end,
		onSwitchOut = function(pokemon)
			if self:isWeather({'desolateland'}) then 
				self:add('message', "The harsh sunlight faded.")    
				self.weatherData.source = null
				self:clearWeather()
				return 
			end
		end,
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk)
			if self:isWeather({'sunnyday', 'desolateland'}) then
				return self:chainModify(1.3)
			end
		end,

		id = "orichalcumpulse",
		name = "Orichalcum Pulse",
		rating = 2.5,
		num = 288,
	},
	['protosynthesis'] = {
		onStart = function(pokemon, source)
			if pokemon.item and pokemon.item == 'boosterenergy' then
				local bestStat = pokemon:findBestStat()
				if bestStat then
					self:boost({[bestStat]=2}, source)
				else
					self:boost({[bestStat]=1}, source)
				end
			end
		end,
		onWeatherChange = function(pokemon, source)
			local bestStat = pokemon:findBestStat()
			if self:isWeather({"sunnyday", "desolateland"}) then
				if bestStat then
					self:boost({[bestStat]=2}, source)
				else
					self:boost({[bestStat]=1}, source)
				end
			elseif self:isWeather({'', 'raindance', 'primordialsea', 'sandstorm', 'hail', 'deltastream'}) then

				self:boost({[bestStat]=-1}, source)
			end

		end,

		id = "protosynthesis",
		name = "Protosynthesis",
		rating = 3,
		num = 281,
	},
	['electromorphosis'] = {
		onDamagingHitOrder = 1,
		onDamagingHit = function(damage, target, source, move)
			self.target.addVolatile('charge')

		end,
		id = "electromorphosis",
		name = "Electromorphosis",
		rating = 2,
		num = 280,
	},
	['myceliumight'] = {
		onFractionalPriorityPriority = -1,
		onFractionalPriority= function(priority, pokemon, target, move)
			if (move.category == 'Status') then
				return -0.1
			end
		end,
		onModifyMove = function(move)
			if (move.category == 'Status') then
				move.ignoreAbility = true
			end
		end,
		id = "myceliummight",
		name = "Mycelium Might",
		rating = 2,
		num = 298
	},
	['lingeringaroma'] = {
		onAfterDamage = function(damage, target, source, move)
			if source and source ~= target and move and move.flags['contact'] then
				local oldAbility = source:setAbility('lingeringaroma', source, 'lingeringaroma', true)
				if oldAbility then
					self:add('-activate', target, 'ability: Lingering Aroma', oldAbility, '[of] ' .. source)
				end
			end
		end,
		id = "lingeringaroma",
		name = "Lingering Aroma",
		rating = 2,
		num = 268,
	},
	['cudchew'] = {
		onEatItem = function(item, pokemon)
			if item.isBerry and not pokemon.volatiles['cudchew'] then
				pokemon:addVolatile('cudchew', pokemon)
				pokemon.volatiles['cudchew'].berry = item
			end
		end,
		onEnd = function(pokemon)
			if pokemon.volatiles['cudchew'] then
				pokemon:removeVolatile('cudchew')
			end
		end,
		condition = {
			duration = 2,
			onStart = function(self, pokemon)
				self:add('-start', pokemon, 'ability: Cud Chew')
			end,
			onResidualOrder = 28,
			onResidualSubOrder = 2,
			onEnd = function(self, pokemon)
				if pokemon.hp and pokemon.volatiles['cudchew'] then
					local item = pokemon.volatiles['cudchew'].berry
					self:add('-activate', pokemon, 'ability: Cud Chew')
					self:add('-enditem', pokemon, item.name, '[eat]')
					if self:singleEvent('Eat', item, nil, pokemon, nil, nil) then
						self:runEvent('EatItem', pokemon, nil, nil, item)
					end
					if item.onEat then
						pokemon.ateBerry = true
					end
				end
			end,
		},
		name = "Cud Chew",
		id = "cudchew",
		rating = 2,
		num = 291,
	},

	['hadronengine'] = {
		onStart = function(pokemon)
			if not self.terrain.set("electricterrain") and self.terrain.is("electricterrain") and pokemon.isGrounded() then
				pokemon:addVolatile("hadronengine")
			end
		end,
		onTerrainChange = function(pokemon)
			if pokemon == self.terrain.getSource() then return end
			if self.terrain.is("electricterrain") and pokemon.isGrounded() then
				pokemon:addVolatile("hadronengine")
			elseif not pokemon.volatiles["hadronengine"].fromBooster then
				pokemon:removeVolatile("hadronengine")
			end
		end,
		onModifySpA = function(spa, pokemon, target, move)
			if pokemon.volatiles["hadronengine"] and pokemon.isGrounded() then
				return spa * 1.5
			end
		end,
		id = "hadronengine",
		name = "Hadron Engine",
		rating = 4.5,
		num = 289,
	},
	['goodasgold'] = {
		onTryHit = function(target, source, move)
			if (move.category == 'Status' and target ~= source) then
				self:add('-immune', target, '[from] ability = Good as Gold')
				return null
			end
		end,
		id = "goodasgold",
		name = "Good as Gold",
		rating = 5,
		num = 283
	},
	['defeatist'] = {
		onModifyAtkPriority = 5,
		onModifyAtk = function(atk, pokemon)
			if pokemon.hp <= pokemon.maxhp/4 then
				return self:chainModify(0.5)
			end
		end,
		onModifySpAPriority = 5,
		onModifySpA = function(atk, pokemon)
			if pokemon.hp <= pokemon.maxhp/4 then
				return self:chainModify(0.5)
			end
		end,

		onModifyDefPriority = 5,
		onModifyDef = function(def, pokemon)
			if pokemon.hp <= pokemon.maxhp/4 then
				return self:chainModify(2)
			end
		end,

		onModifySpDPriority = 2,
		onModifySpD = function(spd, pokemon)
			if pokemon.hp <= pokemon.maxhp/4 then
				return self:chainModify(2)
			end
		end,

		onResidual = function(pokemon)
			pokemon:update()
		end,
		id = "defeatist",
		name = "Defeatist",
		rating = -1,
		num = 129
	},
}
