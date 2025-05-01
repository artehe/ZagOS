//! Everything relating to the bootloader, in our case this is limine

const limine = @import("limine");
const FramebufferRequest = limine.FramebufferRequest;

/// Defines the end marker for the Limine requests.
export const requests_end_marker: limine.RequestsStartMarker linksection(".limine_requests_end") = .{};
/// Defines the start marker for the Limine requests.
export const requests_start_marker: limine.RequestsStartMarker linksection(".limine_requests_start") = .{};

/// Sets the base revision of the limine protocol which is supported by the kernel
pub export const base_revision: limine.BaseRevision linksection(".limine_requests") = .init(3);
/// The framebuffer request structure which is filled by the Limine bootloader.
pub export const framebuffer_request: FramebufferRequest linksection(".limine_requests") = .{};
