package plham.util;
import x10.util.ArrayList;
import x10.util.HashMap;
import x10.util.HashSet;
import x10.util.List;
import x10.util.Map;
import x10.util.Set;
import x10.util.Stack;
import cassia.util.JSON;

public class JSONUtils {

	public static def getDependencyGraph(root:JSON.Value, list:JSON.Value, keyword:String):Map[String,Set[String]] {
		val graph = new HashMap[String,Set[String]]();
		val stack = new Stack[String]();
		for (i in 0..(list.size() - 1)) {
			val name = list(i).toString();
			stack.push(name);
		}
		while (stack.size() > 0) {
			val name = stack.pop();
			Console.OUT.println("#GRAPH " + name + " checking");
			if (!graph.containsKey(name)) {
				graph(name) = new HashSet[String]();
			}
			if (root(name).has(keyword)) {
				val children = root(name)(keyword);
				for (j in 0..(children.size() - 1)) {
					val child = children(j).toString();
					stack.push(child);
					graph(name).add(child);
					Console.OUT.println("#GRAPH " + name + " --> " + child + " created");
				}
			}
		}
		return graph;
	}

	public static def getDependencySortedList(root:JSON.Value, list:JSON.Value, keyword:String):List[String] {
		val graph = getDependencyGraph(root, list, keyword);
		val nodes = new ArrayList[String]();
		nodes.addAll(graph.keySet()); // X10 doesn't allow in-loop state changes.

		// TODO: Efficient algorithm.
		val sorted = new ArrayList[String]();
		while (graph.size() > 0) {
			val numNodes = graph.size();
			for (name in nodes) {
				if (graph(name).size() == 0) {
					sorted.add(name);
					for (parent in graph.keySet()) {
						if (graph(parent).remove(name)) {
							Console.OUT.println("#GRAPH " + parent + " --> " + name + " removed");
						}
					}
					graph.remove(name);
					nodes.remove(name);
					Console.OUT.println("#GRAPH " + name + " removed");
				}
			}
			if (numNodes == graph.size()) {
				throw new Exception("Circular dependency of '" + keyword + "' detected");
			}
		}
		Console.OUT.println("#GRAPH-SORTED " + sorted);
		return sorted;
	}
}
