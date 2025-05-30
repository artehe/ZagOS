//! The limine reuqests start and end markers, which we want to include but don't have
//! much actual use so we keep out the way in here.

const limine = @import("limine");
const std = @import("std");
const log = std.log.scoped(.limine);

/// Defines the end marker for the Limine requests.
export var end_marker: limine.RequestsEndMarker linksection(".limine_requests_end") = .{};
/// Defines the start marker for the Limine requests.
export var start_marker: limine.RequestsStartMarker linksection(".limine_requests_start") = .{};

/// Sets the base revision of the limine protocol which is supported by the kernel
export var base_revision: limine.BaseRevision linksection(".limine_requests") = .init(3);

/// The framebuffer request structure which is filled by the Limine bootloader.
pub export var framebuffer_request: limine.FramebufferRequest linksection(".limine_requests") = .{};

/// Do not proceed if the kernel's base revision is not supported or valid.
pub fn init() void {
    if (!base_revision.isSupported()) {
        @panic("Base revision not supported by bootloader");
    }
    if (!base_revision.isValid()) {
        @panic("Base revision not valid");
    }

    log.debug("Logging requests", .{});
    log.debug("Start Marker: {}", .{start_marker});
    log.debug("End Marker: {}", .{end_marker});
    log.debug("Base Revision: {}", .{base_revision});
    log.debug("Framebuffer: {}", .{framebuffer_request});
}
