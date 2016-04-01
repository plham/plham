package cassia.util.parallel;
import x10.io.Serializer;
import x10.io.Deserializer;
import x10.compiler.Pragma;

/**
 * This class offers some utility functions for broadcast and reduce operations.
 * Some of the code is imported from x10.lang.PlaceGroup. 
 * This is currently a prototype implementation, under development.
 */
public class BroadcastTools {
     public static def broadcastReduce[T](pg: PlaceGroup, reducer:Reducible[T],  cl: ()=>T): T { // This code is modified version of PlaceGroup#broadcastFlat
     	val ser = new Serializer();
     	ser.writeAny(cl);
     	ser.addDeserializeCount(pg.size()-1);
     	val message = ser.toRail();
     	val result:T =  /* 	@Pragma (Pragma.FINISH_SPMD)  */ finish (reducer)  {
     		for (p in pg) {
     			at (p) async {
     			val dser = new x10.io.Deserializer(message);
     			val cls = dser.readAny() as ()=>T;
     			offer cls();
     			}
     		}
     	};
     	return result;
     }
     public static def broadcastReduceNest[T](pg:PlaceGroup, reducer:Reducible[T],  cl: ()=>T) {
     	if(pg.numPlaces() < 32) return broadcastReduce[T](pg,reducer,cl);
     	val ser = new Serializer();
     	ser.writeAny(cl);
     	ser.addDeserializeCount(pg.size()-1);
     	val message = ser.toRail();
     	val result:T =  /* 	@Pragma (Pragma.FINISH_SPMD)  */ finish (reducer)  {
     		for (var i:Long=pg.numPlaces()-1; i>=0; i-=32) {
     			val max = i;
     			at(pg(i)) async {
                	val min = Math.max(max-31, 0);
                	val result0 = finish (reducer) {
                		for (var j:Long=min; j<=max; j++) {
                			at (pg(j)) async {
                				val dser = new x10.io.Deserializer(message);
     							val cls = dser.readAny() as ()=>T;
     							offer cls() as T;
                			}
                		}
                	};
                	offer result0;
            	}
     		}
     	};
     	return result;
     }
     public static workers = new SimpleWorkerPlaceGroup(1L, Place.numPlaces());
     
     static class SimpleWorkerPlaceGroupIterator (min:Long,max:long) implements Iterator[Place] {
    	 var i:Long = min;
    	 public def hasNext() { return i < max;}
    	 public def next() { return Place(i++);}
     }
     public static class SimpleWorkerPlaceGroup (min:Long, max:Long) extends PlaceGroup {

    	public def indexOf(var id:Long):Long {
    		if(contains(id)) return id-min;
    		return -1;
    	}
    	public def contains(var id:Long):Boolean = id >= min && id < max;
    	public def numPlaces():Long  = max-min;
    	
    	public operator this(var i:Long):Place {
    		return Place(i+min);
    	}

    	public def iterator():Iterator[Place]{self!=null} {
    		return new SimpleWorkerPlaceGroupIterator(min,max);
    	}
    	
    	public def broadcastFlat(cl:()=>void) {
    		if(numPlaces() < 32) {
    			val ser = new Serializer();
    			ser.writeAny(cl);
    			ser.addDeserializeCount(this.size()-1);
    			val message = ser.toRail();
    			@Pragma (Pragma.FINISH_SPMD) finish  {
    				for (var j:Long=min; j<max; j++) {
    					at (Place(j)) async {
    						val dser = new x10.io.Deserializer(message);
    						val cls = dser.readAny() as ()=>void;
    						cls();
    					}
    				}
    			}
    		} else {
    			val ser = new Serializer();
    			ser.writeAny(cl);
    			ser.addDeserializeCount(this.size()-1);
    			val message = ser.toRail();
    			@Pragma (Pragma.FINISH_SPMD) finish  {
    				for (var i:Long=this.max-1; i>=min; i-=32) {
    					at(Place(i)) async {
    						val max0 = here.id;
    						val min0 = Math.max(max0-31, this.min);
    						@Pragma (Pragma.FINISH_SPMD) finish  {
    							for (var j:Long=min0; j<=max0; j++) {
    								at (Place(j)) async {
    									val dser = new x10.io.Deserializer(message);
    									val cls = dser.readAny() as ()=>void;
    									cls();
    								}
    							}
    						}
    					}
    				}
    			}
    		}
    	}
     }
}
