sealed class Result<T> { const Result(); }
class Ok<T> extends Result<T> { final T data; const Ok(this.data); }
class Err<T> extends Result<T> { final String message; const Err(this.message); }
