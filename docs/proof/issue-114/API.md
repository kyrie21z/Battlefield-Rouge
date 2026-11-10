# Epic 2 stable boon API (#114)

BoonData extends Resource: enums Sin {SLOTH,FEAR,WRATH,SORROW}, Slot {GUN,BLADE,DASH,OTHER}, Rarity {COMMON,RARE,EPIC,LEGENDARY,DUAL}. Exports id:String, name:String, sin, slot, rarity, core:bool=true (traits false), prerequisites:Array[String], prerequisite_any:Array[String] (OR), required_trait_sin:int=-1, required_trait_count:int=0, description, icon, stat_modifiers:Dictionary, script_hook:Script. Extra parameters:Dictionary supported. Secondary cards set core=false, slot=OTHER. Dual prerequisites may be specific IDs; required_sins:Array[int] allows any core from both listed families.

Each family writes buffs/resources/<family>/pool.tres with BoonPool.cards:Array[BoonData]. BoonCatalog.all() dynamically loads existing sloth/fear/wrath/sorrow/dual/pool.tres; eligible(manager,sin=-1) filters already owned/prerequisites. No central list edits. Stable IDs family_<name>; use same IDs everywhere within family and report list for dual author.

BoonEffect extends RefCounted; var manager:BoonManager; setup(value:BoonManager), on_event(event:StringName,context:Dictionary), tick(delta:float), cleanup(). Each Script instantiates once per manager while any of its cards equipped. manager.has(id:String)->bool, manager.get_boon(id)->BoonData, manager.effect_for(script:Script)->BoonEffect. Cleanup must reverse family-owned effects. No effect reads RunState/groups.

BoonManager Player child: player:CharacterBody3D, stats:Stats, health:Health, weapon:Weapon, blade:MeleeWeapon, dash:PlayerDash, rng:RandomNumberGenerator (zone injects seed, separate stream), slots:Array[BoonSlot] (4; slot.data), traits:Array[BoonData]. request_equip(data)->bool equips if empty; conflicts return false and emit replacement_requested(old:BoonData,new:BoonData). confirm_replace(accept:bool)->bool; equip(data)->bool for trusted restored loadout; remove(id)->bool; all_equipped()->Array[BoonData]; changed signal. dispatch(event,ctx) calls handlers; ctx is mutable synchronously. Callers must retain same Dictionary for before/after. clear() removes everything; cleanup runtime on death/exit. restore(cards:Array) supports Resources list. loadout_changed signal carries Array[BoonData] for Zone persistence.

Events:
- shoot_before / shoot_fired: weapon, source, origin, direction, damage_multiplier (1), proc_depth (0), tag (&gun). shoot_fired once after successful ray; shoot_before once per shot. No event on rejected shot.
- hit_before / hit_after: kind (&gun/&blade/&proc), target (Health owner Node3D), health, hitbox (nullable), source, position, direction, damage (pre-body-part), dealt (after), killed, body_part, proc_depth, tag, critical (bool), cancelled(bool). after fires even when blocked (dealt 0); damage 0 cancels. body_part can be overridden before hit. Native head/body multipliers applied in Health. Only proc_depth==0 is a natural action. All effects MUST gate proc reentry explicitly.
- blade_started: source, blade; blade_struck: source, blade, position, direction (once actual active window begins). blade_finished after recovery.
- parry: source, projectile, position, direction (mutable after reflect), damage (mutable); reflected ownership already transferred.
- dash_started / dash_finished: source, position, origin, direction, duration, distance. started before dashing signal; finished actual end position.
- damage_before / damage_after: source(attacker), target(player), health, damage (post-body-part, before absorption), dealt, cancelled, proc_depth, tag; before can reduce/cancel lethal incoming damage. after fires after HP resolution. Damage_before only after team/parry/invulnerability gates.
- reload_started / reload_finished: weapon, source, empty(bool), ammo; finished only real refill. clock_struck: source,position,perfect(optional).
- enemy_registered / enemy_killed: enemy, target(same enemy), source(Health last source), health, proc_depth, tag; projectiles registered via registry.

Manager runtime services:
- enemies()->Array[Node3D], projectiles()->Array[Node3D]; register_enemy(node)/register_projectile(node) for test or injected entities. Production Events lifecycle registration. targets_in_radius(center:Vector3,radius:float,visible:bool=true)->Array[Node3D] filters dead/team and WORLD LOS. line_clear(from,to)->bool. health_of(node)->Health; hitbox_of(node)->Hitbox; is_enemy(node)->bool.
- apply_damage(target:Node,amount:float,context:Dictionary={})->float uses Health/Hitbox, merges kind=proc, proc_depth=1 default and tag=boon. Refuses depth>4. For secondary effect deriving context always increment original depth. aoe(center,radius,amount,context={}) uses visible unique health.
- grant_shield(amount:float,duration:float=0)->void independent additive barrier after legacy absorber; shield_amount:float; never overwrite old shield damage_absorber.
- set_modifier(source:StringName,modifiers:Dictionary,duration:float=0), remove_modifier(source). Dictionary format {Stats.DAMAGE:{"add":0.0,"mul":1.5}}. Stats same set_modifier/remove_modifier APIs; base/legacy Buff retained.
- set_status(enemy:Node,source:StringName,duration:float,move_scale:float=1,time_scale:float=1,stun:bool=false). statuses combine minimum speed/time, stun OR. clear_status(enemy,source). Parent Enemy exposes boon_movement_scale, boon_time_scale, boon_stunned. Timers manager-driven, pause-safe. A scale0 freezes Enemy + derived SlothAttack, not player clock.
- set_projectile_scale(projectile:Node,source:StringName,scale:float,duration:float=0). projectile has boon_time_scale. freeze_world(duration:float,source:StringName=&"boon_freeze") affects current and newly registered hostile enemies/projectiles and restores. duration0 statuses persistent until clear/cleanup.
- feedback(position:Vector3,color:Color,radius:float=0.5) provides deterministic transient crystal/ring feedback; no global RNG. Family may own richer visuals.

Stats added constants DASH_RECHARGE (base1), DAMAGE_TAKEN(base1), CRIT_CHANCE(base0), CRIT_MULTIPLIER(base2), PROJECTILE_SPEED(base1). DASH_RECHARGE consumed by dash; DAMAGE_TAKEN consumed by manager damage_before; crit chance automatically rolled only >0 on natural gun/blade hits, AFTER family handlers and only if critical=false. Context crit_chance_add adds chance; critical_multiplier tracks applied stat multiplier; base_damage tracks original. Family can override context critical/damage. Legacy no-boon random stream unchanged.

Root #124 owns Zone/RunState new reward flow. Core #114 only adds RunState.boons:Array[Resource], start_new_run clearing, Zone restore/injected RNG/persist hooks. Root should cherry-pick foundation before editing shared lines. No production UI replacement is introduced by114; minimal ui/boon_replace_prompt.gd optional bind(manager).

Additional events: enemy_damage (all registered enemy Health.damage_after); projectile_registered (projectile); enemy_shot (enemy,projectile). Projectile.impacted(target:Node,point:Vector3) after real collision, allow_friendly_fire bool, boon_context Dictionary forwarded to Health. Stats.CLOCK_PROGRESS base1 is read by CapturePoint.

Projectile has boon_hook Callable and impacted(target:Node,point:Vector3). Reflected projectile retains same instance and routes full hit context. Manager clear_world_freeze(source) cancels its freeze. Stats CLOCK_WINDOW=1 and CLOCK_THEME=0 (sin+1) feed CapturePoint and StrikeBar. Damage event dealt excludes overkill; Health.apply_damage return and event dealt both exclude overkill.

补充共享接口：enemy_damage_before 来自所有注册 Health.before_damage；set_status 末参 windup_scale=1.0（真实 Enemy 反应/下一轮起手与 SlothAttack 预警读取）；Stats.MELEE_ARC=1 乘真实刀弧；shoot_before 的 cancel_primary=true 只替换子弹实现，保留扣弹、枪后坐与成功射击事件。伤害 target/health/hitbox 总是以本次实际目标为准，防止复制旧上下文时沿用旧目标。

Incoming context skip_damage_multiplier=true skips only the repeated Stats.DAMAGE_TAKEN multiplier for fixed deferred debt; all before_damage listeners, immunity and shields still apply. Health after_damage includes absorbed and resolved_damage=actual HP damage+absorption. Random crit damage additionally applies critical_damage_scale. Player-owned Projectile registration and actual parry consume PROJECTILE_SPEED once via metadata; families supply raw projectile speed. Blade hit_after may set skip_impact=true when its ability already applies a physical impulse, preserving that impulse instead of overwriting with the basic shove.

Health intrinsic barrier: shield_points=0, max_shield=0, shield_regeneration_rate=0, shield_regeneration_delay=3. grant_shield(amount), regenerate_shield(amount), break_shield()->removed. set_shield_regeneration_blocked(source, bool) composes independent blockers; readonly shield_regeneration_blocked. Manager set_status final optional block_shield_regen=false uses its own blocker source and cleanup. ctx.true_damage skips body multiplier and shields, preserving team/invulnerability/death checks. Current production maps instantiate no shielded enemies; tests use the actual Health barrier.

set_status final optional attack_scale=1.0 controls only Enemy attack/reaction timers, SlothAttack clock and SlothEnemy attack cooldown. It does not modify movement, actor animation or defensive exposure/recovery clocks.


## Outgoing full-damage composition

`damage_scaled` defaults to `false`: a raw player-owned amount receives `Stats.DAMAGE` once before `hit_before` handlers, then becomes `true`. Registered enemy `Health.before_damage` applies the same guarded rule to direct Health callers. Enemy/environmental damage is never multiplied by player offense. True damage still receives outgoing offense; it bypasses mitigation/barriers as before.

Natural pistol and blade damage already includes offense and sets `damage_scaled=true`. Player-owned Projectile instances with no hook receive the manager's hit pipeline during registration; reflected projectiles preserve an existing hook. A caller deriving a new fixed amount from a copied context must explicitly reset `damage_scaled=false`. A caller replaying settled damage must preserve `true`. The flag controls outgoing offense only: target vulnerability, shields, immunity, and the normal Hitbox/Health order still apply.

Sloth calculates `(base + shot_pressure) * current_damage + actual_damage_pressure * inertia`, then applies its explicit detonation multiplier. Its burst and rebound carry `damage_scaled=true`. Thus actual HP loss is never boosted twice. The raw portion uses offense at detonation time. Sorrow's fixed incoming debt remains its resolved first-hit quota; a 200% debt retaliation is twice the settled debt and carries `true`, so it cannot receive outgoing offense again.

Cross-family real-HP evidence belongs to the complete-pool #123 fixture (`tests/boon_damage_scaling_test.tscn`), while `tests/boon_pipeline_test.tscn` independently verifies this API without family resources.
