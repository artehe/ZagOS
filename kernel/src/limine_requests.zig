//! The limine reuqests start and end markers, which we want to include but don't have
//! much actual use so we keep out the way in here.

const limine = @import("limine");

/// Defines the end marker for the Limine requests.
export const requests_end_marker: limine.RequestsStartMarker linksection(".limine_requests_end") = .{};
/// Defines the start marker for the Limine requests.
export const requests_start_marker: limine.RequestsStartMarker linksection(".limine_requests_start") = .{};
