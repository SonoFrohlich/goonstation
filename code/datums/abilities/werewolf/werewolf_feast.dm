/datum/targetable/werewolf/werewolf_feast
	name = "Maul victim"
	desc = "Feast on the target to quell your hunger."
	icon_state = "feast"
	targeted = 1
	target_nodamage_check = 1
	max_range = 1
	cooldown = 10
	pointCost = 0
	when_stunned = 0
	not_when_handcuffed = 1
	werewolf_only = 1
	restricted_area_check = 2

	cast(mob/target)
		if (!holder)
			return 1

		var/mob/living/M = holder.owner

		if (!M || !target || !ismob(target))
			return 1

		if (M == target)
			boutput(M, "<span class='alert'>Why would you want to maul yourself?</span>")
			return 1

		if (GET_DIST(M, target) > src.max_range)
			boutput(M, "<span class='alert'>[target] is too far away.</span>")
			return 1

		if (!ishuman(target)) // Critter mobs include robots and combat drones. There's not a lot of meat on them.
			boutput(M, "<span class='alert'>[target] probably wouldn't taste very good.</span>")
			return 1

		if (isnpc(target)) // Critter mobs include robots and combat drones. There's not a lot of meat on them.
			boutput(M, "<span class='alert'>Something about [target]'s smell puts you off feasting on them.</span>")
			return 1

		if (!target.lying)
			boutput(M, "<span class='alert'>[target] needs to be lying on the ground first.</span>")
			return 1

		logTheThing(LOG_COMBAT, M, "starts to maul [constructTarget(target,"combat")] at [log_loc(M)].")
		actions.start(new/datum/action/bar/private/icon/werewolf_feast(target, src), M)
		return 0

/datum/action/bar/private/icon/werewolf_feast
	duration = 250
	interrupt_flags = INTERRUPT_MOVE | INTERRUPT_ACT | INTERRUPT_STUNNED | INTERRUPT_ACTION
	id = "werewolf_feast"
	icon = 'icons/mob/critter_ui.dmi'
	icon_state = "devour_over"
	var/mob/living/target
	var/datum/targetable/werewolf/werewolf_feast/feast
	var/times_attacked = 0
	var/do_we_get_points = FALSE // For the specialist objective. Did we feed on the target enough times?

	New(Target, Feast)
		target = Target
		feast = Feast
		..()

	onStart()
		..()

		var/mob/living/M = owner
		var/datum/abilityHolder/A = feast.holder

		if (!feast || GET_DIST(M, target) > feast.max_range || target == null || M == null || !ishuman(target) || !ishuman(M) || !A || !istype(A))
			interrupt(INTERRUPT_ALWAYS)
			return

		// What do we do if the body is dead?
		if (target.stat == 2)
			if (target.reagents)
				if (target.reagents.has_reagent("formaldehyde", 15))
					boutput(M, "<span class='alert'>Urgh, this cadaver tastes horrible. Better find some chemical free meat.</span>")
					return

			var/mob/living/carbon/human/H = target
			//If they are at the decay or greater decomp stage, no eat
			if (istype(H) && H.decomp_stage >= DECOMP_STAGE_DECAYED)
				boutput(M, "<span class='alert'>Urgh, this cadaver tastes horrible. Better find some fresh meat.</span>")
				return

		A.locked = 1
		playsound(M.loc, pick('sound/voice/animal/werewolf_attack1.ogg', 'sound/voice/animal/werewolf_attack2.ogg', 'sound/voice/animal/werewolf_attack3.ogg'), 50, 1)
		M.visible_message("<span class='alert'><B>[M] lunges at [target]!</b></span>")

	onUpdate()
		..()

		var/mob/living/M = owner
		var/datum/abilityHolder/A = feast.holder
		var/mob/living/carbon/human/HH = target

		if (!feast || GET_DIST(M, HH) > feast.max_range || HH == null || M == null || !ishuman(HH) || !ishuman(M) || !A || !istype(A) || (!HH.lying))
			interrupt(INTERRUPT_ALWAYS)
			return

		if (!GET_COOLDOWN(M, "ww feast"))
			M.werewolf_attack(HH, "feast")
			ON_COOLDOWN(M, "ww feast", 2.5 SECONDS) // Enough time between attacks for them to happen 9 times
			times_attacked += 1

		if (HH.decomp_stage <= DECOMP_STAGE_DECAYED && !(isnpcmonkey(HH)) && (times_attacked >= 7)) // Can't farm npc monkeys.
			src.do_we_get_points = TRUE

	onEnd()
		..()

		var/datum/abilityHolder/A = feast.holder
		var/mob/living/M = owner
		var/mob/living/carbon/human/HH = target

		// AH parent var for AH.locked vs. specific one for the feed objective.
		// Critter mobs only use one specific type of abilityHolder for instance.
		if (istype(A, /datum/abilityHolder/werewolf))
			var/datum/abilityHolder/werewolf/W = A
			if (W.feed_objective && istype(W.feed_objective, /datum/objective/specialist/werewolf/feed/))
				if (src.do_we_get_points == 1)
					if (istype(HH) && HH.bioHolder)
						if (!W.feed_objective.mobs_fed_on.Find(HH.bioHolder.Uid))
							W.feed_objective.mobs_fed_on.Add(HH.bioHolder.Uid)
							W.feed_objective.feed_count++
							APPLY_ATOM_PROPERTY(M, PROP_MOB_STAMINA_REGEN_BONUS, "feast-[W.feed_objective.feed_count]", 2)
							M.add_stam_mod_max("feast-[W.feed_objective.feed_count]", 10)
							M.max_health += 10
							health_update_queue |= M
							W.lower_cooldowns(0.1)
							boutput(M, "<span class='notice'>You finish chewing on [HH], but what a feast it was!</span>")
						else
							boutput(M, "<span class='alert'>You've mauled [HH] before and didn't like the aftertaste. Better find a different prey.</span>")
					else
						boutput(M, "<span class='alert'>What a meagre meal. You're still hungry...</span>")
				else
					boutput(M, "<span class='alert'>What a meagre meal. You're still hungry...</span>")
			else
				boutput(M, "<span class='alert'>You finish chewing on [HH].</span>")
		else
			boutput(M, "<span class='alert'>You finish chewing on [HH].</span>")

		if (A && istype(A))
			A.locked = 0

	onInterrupt()
		..()

		var/datum/abilityHolder/A = feast.holder
		var/mob/living/M = owner
		var/mob/living/carbon/human/HH = target

		if (istype(A, /datum/abilityHolder/werewolf))
			var/datum/abilityHolder/werewolf/W = A
			if (W.feed_objective && istype(W.feed_objective, /datum/objective/specialist/werewolf/feed/))
				if (src.do_we_get_points == 1)
					if (istype(HH) && HH.bioHolder)
						if (!W.feed_objective.mobs_fed_on.Find(HH.bioHolder.Uid))
							W.feed_objective.mobs_fed_on.Add(HH.bioHolder.Uid)
							W.feed_objective.feed_count++
							APPLY_ATOM_PROPERTY(M, PROP_MOB_STAMINA_REGEN_BONUS, "feast-[W.feed_objective.feed_count]", 1)
							M.add_stam_mod_max("feast-[W.feed_objective.feed_count]", 5)
							M.max_health += 10
							health_update_queue |= M
							W.lower_cooldowns(0.1)
							boutput(M, "<span class='notice'>Your feast was interrupted, but it satisfied your hunger for the time being.</span>")
						else
							boutput(M, "<span class='alert'>You've mauled [HH] before and didn't like the aftertaste. Better find a different prey.</span>")
					else
						boutput(M, "<span class='alert'>Your feast was interrupted and you're still hungry...</span>")
				else
					boutput(M, "<span class='alert'>Your feast was interrupted and you're still hungry...</span>")
			else
				boutput(M, "<span class='alert'>Your feast was interrupted.</span>")
		else
			boutput(M, "<span class='alert'>Your feast was interrupted.</span>")

		if (A && istype(A))
			A.locked = 0
