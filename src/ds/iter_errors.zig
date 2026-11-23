pub const IteratorError = error{
    /// `next` was called after the last value (`hasNext` is false)
    NoSuchElement,
    /// `peek`, `changeHere` or `delete` was called with no node at the position
    IllegalState,
};