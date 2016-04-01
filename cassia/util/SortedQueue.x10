package cassia.util;
import x10.util.List;

public interface SortedQueue[T] extends /*Collection[T],*/ Iterable[T] {

	public def push(x:T):Boolean;

	public def pop():T;

    public def peek():T;

	public def add(x:T):Boolean;

	public def remove(x:T):Boolean;

    public def removeAllWhere(p:(T)=>Boolean):Boolean;

	public def size():Long;

	public def contains(x:T):Boolean;

	/** An iterator that returns elements in an undefined order. */
	public def iterator():Iterator[T];

	public def toList():List[T];
}
