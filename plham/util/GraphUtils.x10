package plham.util;
import x10.util.ArrayList;
import x10.util.HashMap;
import x10.util.HashSet;
import x10.util.List;
import x10.util.Map;
import x10.util.Set;
import x10.util.Stack;
import x10.util.Random;
import x10.util.Pair;

public class GraphUtils {

	/**
	 * Convert adjacency pairs to adjacency lists.
	 */
	public static def toAdjacencySet[T](nodes:Set[T], pairs:Set[Pair[T,T]]):Map[T,Set[T]] {
		val graph = new HashMap[T,Set[T]]();
		for (i in nodes) {
			graph(i) = new HashSet[T]();
		}
		for (key in pairs) {
			val i = key.first; // From
			val j = key.second; // To
			graph(i).add(j);
		}
		return graph;
	}

	public static def getConnectedComponents[T](nodes:Set[T], pairs:Set[Pair[T,T]]):List[Set[T]] {
		val graph = toAdjacencySet(nodes, pairs);
		return getConnectedComponents(graph);
	}

	/**
	 * Find connected components of the <b>undirected</b> graph.
	 * @param graph  adjacency list (all nodes must be in the keys)
	 * @return a list of connected components
	 */
	public static def getConnectedComponents[T](graph:Map[T,Set[T]]):List[Set[T]] {
		val out = new ArrayList[Set[T]]();
		val checked = new HashSet[T]();
		for (root in graph.keySet()) {
			if (checked.contains(root)) {
				continue;
			}

			Console.OUT.println("#GRAPH " + root + " checking");
			val visited = new HashSet[T]();
			val stack = new Stack[T]();
			stack.push(root);
			while (stack.size() > 0) {
				val key = stack.pop();
				if (visited.contains(key)) {
					continue;
				}
				visited.add(key);
				Console.OUT.println("#GRAPH " + key + " checking(sub)");
				for (child in graph(key)) {
					assert graph(child).contains(key) : "Undirected graph only supported";
					stack.push(child);
					Console.OUT.println("#GRAPH " + key + " --> " + child + " connected");
				}
			}
			out.add(visited);
			checked.addAll(visited);
		}
		Console.OUT.println("#GRAPH finished");
		return out;
	}

	public static def dump[T](graph:Map[T,Set[T]]) {
		for (i in graph.keySet()) {
			Console.OUT.print("# ");
			Console.OUT.print(i + ": ");
			for (j in graph(i)) {
				Console.OUT.print(j + " ");
			}
			Console.OUT.println();
		}
	}

	public static def dump[T](list:List[Set[T]]) {
		for (cc in list) {
			Console.OUT.print("# ");
			for (j in cc) {
				Console.OUT.print(j + " ");
			}
			Console.OUT.println();
		}
	}

	public static def main(args:Rail[String]) {
		var T:Long = 100;
		var N:Long = 10;
		if (args.size > 0) {
			T = Long.parse(args(0));
		}
		if (args.size > 1) {
			N = Long.parse(args(1));
		}
		val random = new Random();

		val graph = new HashMap[Long,Set[Long]]();
		for (i in 0..(N - 1)) {
			graph(i) = new HashSet[Long]();
		}
		for (t in 1..T) {
			val i = random.nextLong(N);
			val j = random.nextLong(N);
			graph(i).add(j);
			graph(j).add(i);
		}
		dump(graph);

		val C = getConnectedComponents(graph);
		dump(C);

		Console.OUT.println("#### #### #### ####");

		val pairs = new HashSet[Pair[Long,Long]]();
		for (i in 0..(N - 1)) {
			for (j in graph(i)) {
				pairs.add(Pair[Long,Long](i, j));
			}
		}

		val pG = toAdjacencySet(graph.keySet(), pairs);
		dump(pG);

		val pC = getConnectedComponents(pG);
		dump(pC);
	}
}
