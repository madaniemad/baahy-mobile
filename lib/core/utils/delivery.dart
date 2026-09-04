/// Same-day dispatch cutoff, in local time.
///
/// Orders placed before this hour go out the same day; after it they go out the
/// next working day. Friday is not a working day.
///
/// This lived as a bare `16` in three separate files — the cart countdown, the
/// product-page delivery range, and the order-confirmed screen — which is exactly
/// how the three of them end up promising different things. Change it here.
const int kDispatchCutoffHour = 14;
