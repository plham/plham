package cassia.util.parallel;
import x10.util.List;
import x10.util.ArrayList;

/**
 * A reduction operator that reduce List[T] using {@link ConcatenatedList}.
 */

public struct ConcatenatedListReducer[T] implements Reducible[List[T]] {
	
	public def zero():List[T] = new ConcatenatedList[T]();
	
	public operator this(a:List[T], b:List[T]):List[T] {
		if(a.size() == 0L) return b;
		if(b.size() == 0L) return a;
		if(a instanceof ConcatenatedList[T]) {
			atomic {(a as ConcatenatedList[T]).addList(b);}
			return a; 
		} else {
			val result = new ConcatenatedList[T]();
			result.addList(a);
			result.addList(b);
			return result;
		}
	}

}
