-- UTCore_Events.lua
-- Centralized event listener registration and timer dispatcher.
-- Phase 1 stub — no periodic handlers needed until Phase 2/3.

UTCore = UTCore or {}
UTCore._periodicHandlers = {}

-- Phase 2+ will add:
--   UTCore.registerPeriodicHandler(traitId, intervalEvent, handlerFn)
--   UTCore.unregisterPeriodicHandler(traitId)
