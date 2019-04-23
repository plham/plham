package plham.util;
import x10.util.*;
import cassia.util.*;

public class CentricAllocManager[T] extends DistAllocManager[T] {
    private var body:List[T] = null;

    public def this() {}
    public def getRangedList(Place, config:JSON.Value, range: LongRange): RangedList[T] {
        assert body != null: "CentricAllocManager: body is null, setTotalCount has not called yet!";
	return new RangedListView[T](body, range);
    }
    public def setTotalCount(size:Long) {
        this.body = new ArrayList[T](size);
    }   
    public def getBody() { return body; }

}

