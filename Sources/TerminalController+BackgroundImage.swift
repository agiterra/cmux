// AGITERRA-BG: v2 surface.set_background socket handler (new file).
//
// Implements `surface.set_background` — sets or clears a Ghostty per-surface
// background image at runtime. Crew themes can call this to apply theme.json
// `background.images[paneName]` to the right surface without bouncing the app.

import Foundation

extension TerminalController {
    private static let bgImageValidFits: Set<String> = ["contain", "cover", "stretch", "none"]
    private static let bgImageValidPositions: Set<String> = [
        "center",
        "top", "bottom", "left", "right",
        "top-left", "top-right", "bottom-left", "bottom-right",
        "tl", "tr", "bl", "br",
    ]
    private static let bgImageSurfaceUnavailable = String(
        localized: "socket.surfaceSetBackground.error.surfaceUnavailable",
        defaultValue: "Terminal surface is not available"
    )

    func v2SurfaceSetBackground(params: [String: Any]) -> V2CallResult {
        guard let tabManager = v2ResolveTabManager(params: params) else {
            return .err(code: "unavailable", message: "TabManager not available", data: nil)
        }

        let clear = v2Bool(params, "clear") ?? false
        let rawImage = v2String(params, "image")
        if !clear {
            guard let image = rawImage, !image.isEmpty else {
                return .err(
                    code: "invalid_params",
                    message: "Missing image (set clear=true to remove)",
                    data: nil
                )
            }
            guard image.hasPrefix("/") else {
                return .err(
                    code: "invalid_params",
                    message: "image must be an absolute path",
                    data: ["image": image]
                )
            }
        }

        let opacity = v2Double(params, "opacity")
        if let opacity, !(0.0...1.0).contains(opacity) {
            return .err(
                code: "invalid_params",
                message: "opacity must be in [0.0, 1.0]",
                data: ["opacity": opacity]
            )
        }
        let fit = v2String(params, "fit")
        if let fit, !Self.bgImageValidFits.contains(fit) {
            return .err(
                code: "invalid_params",
                message: "fit must be one of: \(Self.bgImageValidFits.sorted().joined(separator: ","))",
                data: ["fit": fit]
            )
        }
        let position = v2String(params, "position")
        if let position, !Self.bgImageValidPositions.contains(position) {
            return .err(
                code: "invalid_params",
                message: "position must be one of: \(Self.bgImageValidPositions.sorted().joined(separator: ","))",
                data: ["position": position]
            )
        }
        let repeatFlag = v2Bool(params, "repeat")

        var result: V2CallResult = .err(
            code: "internal_error",
            message: "Failed to set background",
            data: nil
        )
        v2MainSync {
            guard let ws = v2ResolveWorkspace(params: params, tabManager: tabManager) else {
                result = .err(code: "not_found", message: "Workspace not found", data: nil)
                return
            }
            let surfaceId: UUID?
            if params["surface_id"] != nil {
                surfaceId = v2UUID(params, "surface_id")
                guard surfaceId != nil else {
                    result = .err(
                        code: "not_found",
                        message: "Surface not found for the given surface_id",
                        data: nil
                    )
                    return
                }
            } else {
                surfaceId = ws.focusedPanelId
            }
            guard let surfaceId else {
                result = .err(code: "not_found", message: "No focused surface", data: nil)
                return
            }
            guard let terminalPanel = ws.terminalPanel(for: surfaceId) else {
                result = .err(
                    code: "invalid_params",
                    message: "Surface is not a terminal",
                    data: ["surface_id": surfaceId.uuidString]
                )
                return
            }
            guard let liveSurface = terminalPanel.surface.liveSurfaceForGhosttyAccess(
                reason: "v2SurfaceSetBackground"
            ) else {
                result = .err(
                    code: "surface_unavailable",
                    message: Self.bgImageSurfaceUnavailable,
                    data: ["surface_id": surfaceId.uuidString]
                )
                return
            }

            let overrides = Self.buildBackgroundImageOverrides(
                image: clear ? nil : rawImage,
                opacity: clear ? nil : opacity,
                fit: clear ? nil : fit,
                position: clear ? nil : position,
                repeatFlag: clear ? nil : repeatFlag
            )
            GhosttyApp.shared.applySurfaceBackgroundImage(liveSurface, overrides: overrides)
            terminalPanel.surface.forceRefresh(reason: "v2SurfaceSetBackground")

            let windowId = v2ResolveWindowId(tabManager: tabManager)
            result = .ok([
                "workspace_id": ws.id.uuidString,
                "workspace_ref": v2Ref(kind: .workspace, uuid: ws.id),
                "window_id": v2OrNull(windowId?.uuidString),
                "window_ref": v2Ref(kind: .window, uuid: windowId),
                "surface_id": surfaceId.uuidString,
                "surface_ref": v2Ref(kind: .surface, uuid: surfaceId),
                "image": clear ? v2OrNull(nil) : v2OrNull(rawImage),
                "opacity": clear ? v2OrNull(nil) : v2OrNull(opacity ?? 1.0),
                "fit": clear ? v2OrNull(nil) : v2OrNull(fit ?? "contain"),
                "position": clear ? v2OrNull(nil) : v2OrNull(position ?? "center"),
                "repeat": clear ? v2OrNull(nil) : v2OrNull(repeatFlag ?? false),
                "cleared": clear,
            ])
        }
        return result
    }

    private static func buildBackgroundImageOverrides(
        image: String?,
        opacity: Double?,
        fit: String?,
        position: String?,
        repeatFlag: Bool?
    ) -> String {
        var lines: [String] = []
        // Always emit the image key. An empty value resets the surface to no
        // background image (the clear path); a path sets one.
        lines.append("background-image = \(image ?? "")")
        if let opacity {
            lines.append("background-image-opacity = \(opacity)")
        }
        if let fit {
            lines.append("background-image-fit = \(fit)")
        }
        if let position {
            lines.append("background-image-position = \(position)")
        }
        if let repeatFlag {
            lines.append("background-image-repeat = \(repeatFlag ? "true" : "false")")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
