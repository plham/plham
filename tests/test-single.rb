# A test script for plham's sample projects.
# 
# To run tests for samples/SomeExperiments, make directory named tests/SomeExperiments, copy tests/test-template.rb to tests/SomeExperiments, 
# and place config.json and correct_output.txt under test/SomeExperiments.

SPEC_PROJ = ARGV[0]

PLHAM_DIR = File.expand_path("..")
PLHAM_TEST_DIR = File.expand_path(".")
PLHAM_TEST_BUILD = File.expand_path("./build")
PLHAM_SAMPLES_DIR = File.expand_path("../samples")
CASSIAX10LIB_DIR = File.expand_path("../cassiaX10lib")

ENV["PLHAM_DIR"] = PLHAM_DIR
ENV["PLHAM_TEST_DIR"] = PLHAM_TEST_DIR

X10PATH = ENV["X10PATH"].nil? ? "" : (ENV["X10PATH"].chomp("/") + "/")

X10CC_OPT = " -sourcepath #{PLHAM_DIR}:#{CASSIAX10LIB_DIR} -d #{PLHAM_TEST_BUILD} "
X10_OPT = " -classpath #{PLHAM_TEST_BUILD} "
CC = X10PATH + "x10c #{X10CC_OPT}  "
RUN = X10PATH + "x10 #{X10_OPT} "

def dfs(dir)
    dir.chomp!("/")
    Dir.entries(dir).each do |elem|
        next if elem.start_with?('.')
        elem = File.expand_path(elem, dir)
        if File.directory?(elem) then
            dfs(elem)
        elsif elem.end_with?("test.rb")
            proj_name = dir.split("/").last
            eval(File.read(elem))
        end
    end
end

dfs(PLHAM_TEST_DIR + "/" + SPEC_PROJ)
