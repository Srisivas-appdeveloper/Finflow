/// The lifecycle of data shown on a screen.
///
/// Controllers expose one of these so pages can render loading, empty, error
/// and content states consistently with an exhaustive `switch`.
sealed class ViewState<T> {
  const ViewState();
}

final class ViewLoading<T> extends ViewState<T> {
  const ViewLoading();
}

final class ViewEmpty<T> extends ViewState<T> {
  const ViewEmpty();
}

final class ViewData<T> extends ViewState<T> {
  const ViewData(this.data);
  final T data;
}

final class ViewError<T> extends ViewState<T> {
  const ViewError(this.message);
  final String message;
}
