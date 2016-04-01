package cassia.util.parallel;
import x10.util.List;
import x10.util.ArrayList;
import x10.util.AbstractCollection;

/**
 * An implementation of List to concatenate multiple lists.
 * It only remembers the references to the input lists.
 * The toArrayList() method generates a concatenated result as an ArrayList instance. 
 */
public class ConcatenatedList[T] extends AbstractCollection[T] implements List[T] {
	private var arrays:ArrayList[List[T]] = new ArrayList[List[T]]();
	private var _size:Long = 0L; 

	public def addList(array:List[T]) {
		if(array.size() == 0L) return;
		if(array instanceof ConcatenatedList[T]) {
			arrays.addAll((array as ConcatenatedList[T]).arrays);
			_size += array.size();
		} else {
			arrays.add(array);
			_size += array.size();
		}
	}
	
	public def toArrayList(): ArrayList[T] {
		var size:Long = 0L, index:Long = 0L;
		for(a in arrays) {
			size += a.size();
		}
		val result:ArrayList[T] = new ArrayList[T](size);
		for(a in arrays) {
			result.addAll(a);
		}
		return result;
	}
	
	public def size():Long {
		return _size;
	}
	
	public def remove(var v:T):Boolean {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public def contains(var y:T):Boolean {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public def add(var v:T):Boolean {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public def clone():x10.util.Collection[T] {
		return toArrayList();
	}
	
	public def getLast():T {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public operator this(var index:Long):T {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}

	public def indexOf(var v:T):Long {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public def indexOf(var index:Long, var v:T):Long {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public def iteratorFrom(var i:Long):x10.util.ListIterator[T] {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public def subList(var fromIndex:Long, var toIndex:Long):List[T] {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public operator this(i:Long)=(v:T):T  = set(v,i);

	public def set(v:T, i:Long):T {
		throw new Error("not implemented yet");
	}
	
	public def removeLast():T {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public def getFirst():T {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public def equals(var that:Any):Boolean {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");
	}
	
	public def addBefore(var i:Long, var v:T):void {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}
	
	public def iterator():x10.util.ListIterator[T] {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}
	
	public def toString():String {
		return "Concatenated List: body[" + arrays + "]";
	}
	
	public def lastIndexOf(var v:T):Long {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}
	
	public def indices():List[Long] {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}
	
	public def reverse():void {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}
	
	public def removeAt(var i:Long):T {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}
	
	public def removeFirst():T {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}
	
	public def sort(var cmp:(T,T)=>Int):void {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}
	
	public def lastIndexOf(var index:Long, var v:T):Long {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}
	
	public def sort():void {
		// TODO: auto-generated method stub
		throw new Error("not implemented yet");		
	}
}
