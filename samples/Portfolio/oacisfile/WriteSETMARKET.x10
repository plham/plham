//x10c++ -nooutput -o WriteSETMARKET.out WriteSETMARKET.x10

public class WriteSETMARKET {

	public static def main(args:Rail[String]) {
		var v:Long = Int.parseInt(args(0));		
		var n:Long = Int.parseInt(args(1));
		assert n>0: "WriteSETMARKET1Error";
		var numNPAgent:Long;
		var numBPAgent:Long;

		if(args.size>2){
			numNPAgent = 4*Int.parseInt(args(2))/5;
			numBPAgent = Int.parseInt(args(2))/5;
		}

		//Console.OUT.println("n="+n);
		if(v==1){
			var out:String = setMarket1(n);
			Console.OUT.print(out);
		}else if(v==2){
			var out2:String = setMarket2(n);
			Console.OUT.print(out2);
		}else if(v==3){
			var out3:String = setCashAmount(n);
			Console.OUT.print(out3);
		}else if(v==4){
			var out4:String = setLocalAgent1(n);
			Console.OUT.print(out4);
		}else if(v==5){
			var out5:String = setLocalAgent2(n);
			Console.OUT.print(out5);
		}
	}

	public static def setMarket1(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s +"\"market-"+ i +"\"";
			if(i!=n){
				s = s +",";
			}
		}
		return s;
	}

	public static def setMarket2(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s +element(i);
			if(i!=n){
				s = s +",\n\n";
			}
		}
		return s;

	}

	public static def element(i:Long):String{
		var s:String = "\t \"market-"+i+"\": {\n \t \t \"extends\": \"class-Market\" \n \t }";
		return s;
	}

	public static def setCashAmount(i:Long):String{
		var s:String = new String();
		var c:Double = 15000*i;
		s = c.toString();
		return s;
	}

	public static def setLocalAgent1(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s +"\"normalLocal"+ i +"\"";
			s = s +",";
		}
		for(var i:Long = 1; i <= n; ++i){
			s = s +"\"baselLocal"+ i +"\"";
			if(i!=n){
				s = s +",";
			}
		}
		return s;
	}

	public static def setLocalAgent2(n:Long):String{
		var s:String = new String();
		for(var i:Long = 1; i <= n; ++i){
			s = s + normalLocal(i);
			s = s +",\n\n";
		}
		for(var i:Long = 1; i <= n; ++i){
			s = s +baselLocal(i);
			if(i!=n){
				s = s +",\n\n";
			}
		}
		return s;
	}

	public static def normalLocal(i:Long):String{
		var s:String = "\"normalLocal" + i + "\": { \n \t \t \"extends\": \"FCNMarkowitzPortfolioAgent\", \n \t \t \"cashAmount\": 15000.0, \n \t \t \"numAgents\": NUMNORMALLOCAL, \n \t \t \"accessibleMarkets\": [\"market-" + i + "\"] \n \t }";
		return s;
	}

	public static def baselLocal(i:Long):String{
		var s:String = "\"baselLocal" + i + "\": { \n \t \t \"class\": \"FCNBaselMarkowitzPortfolioAgent\", \n \t \t \"extends\": \"FCNMarkowitzPortfolioAgent\", \n \t \t \"numAgents\": NUMBASELLOCAL, \n \t \t \"cashAmount\": 15000.0, \n \t \t \"distanceType\": \"Manhattan\", \n \t \t \"riskType\": \"VaR\", \n \t \t \"confInterval\": 0.99, \n \t \t \"numDaysVaR\": 10, \n \t \t \"sizeDistVaR\": 250, \n \t \t \"coMarketRisk\": 125.0, \n \t \t \"threshold\": 0.08, \n \t \t \"isLimitVariable\": true, \n \t \t \"underLimitPriceRate\": 0.5, \"overLimitPriceRate\": 1.5, \n \t \t \"underLimitPrice\": 200, \n \t \t \"overLimitPrice\": 600, \n \t \t \"accessibleMarkets\": [\"market-" + i +  "\"] \n \t }"; 
		return s;
	}

}


