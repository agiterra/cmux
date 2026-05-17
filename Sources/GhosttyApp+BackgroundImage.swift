// AGITERRA-BG: per-surface background-image overrides (new file; no shared edits).
//
// Applies ad-hoc background-image overrides to a single Ghostty surface. Mirrors
// the soft-reload pattern in GhosttyApp+SurfaceConfigurationReload.swift but
// layers an inline-config snippet on top via the public
// ghostty_config_load_string C API. ghostty_surface_update_config re-derives
// DerivedConfig on each call and the renderer diffs bg_image fields, so the
// change is live without re-finalize.
extension GhosttyApp {
    func applySurfaceBackgroundImage(
        _ surface: ghostty_surface_t,
        overrides: String
    ) {
        guard let newConfig = ghostty_config_new() else { return }
        _ = loadDefaultConfigFilesWithLegacyFallback(newConfig)
        let trimmed = overrides.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let syntheticPath = "/__cmux_inline__/cmux-bg-image.conf"
            trimmed.withCString { contents in
                syntheticPath.withCString { path in
                    ghostty_config_load_string(
                        newConfig,
                        contents,
                        UInt(trimmed.lengthOfBytes(using: .utf8)),
                        path
                    )
                }
            }
        }
        ghostty_surface_update_config(surface, newConfig)
#if DEBUG
        cmuxDebugLog("surface.bg_image.apply len=\(trimmed.count)")
#endif
        ghostty_config_free(newConfig)
    }
}
