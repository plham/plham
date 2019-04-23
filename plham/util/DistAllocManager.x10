package plham.util;
import x10.util.*;
import cassia.util.*;

public abstract class DistAllocManager[T] {
    public abstract def getRangedList(Place, config:JSON.Value, LongRange): RangedList[T];
    public abstract def setTotalCount(size:Long): void;
}

