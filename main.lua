-- DScrete Items -- Gen1Recomp Mod API 2 entrypoint.
--
-- Keep the root entry deliberately small. Feature modules are loaded from this
-- mod's own directory through mod:read + sandboxed load, so release builds do
-- not depend on engine internals or a second runtime.

return function(mod)
  -- Phase modules are installed by later commits. This entry exists now so the
  -- repository is already a valid, loadable Mod API 2 package.
  mod.exports.version = mod.version
end
