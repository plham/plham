test_dir = "tests/" + proj_name
proj_dir = "samples/" + proj_name
proj_main_src_abspath = Dir["#{PLHAM_DIR}/#{proj_dir}/*Main.x10"].first
proj_main_src = proj_main_src_abspath.split("/").last
proj_main = proj_main_src.chomp(".x10")
test_configs = Dir["#{PLHAM_DIR}/#{test_dir}/config*.json"]

proj_clazz = "#{proj_dir}/#{proj_main}".gsub(/\//,'.') 

cc_cmd = "#{CC} #{proj_dir}/#{proj_main_src}"
Dir.chdir(PLHAM_DIR)
STDERR.puts(cc_cmd)
system(cc_cmd)

test_configs.each do |test_config|
  test_id = test_config.match(/^.+config(?<id>.*)\.json$/)[:id] || ""
  conf_name = "config#{test_id}.json"
  correct_output_file = "#{test_dir}/correct_output#{test_id}.txt"
  program_output_file = "#{test_dir}/program_output#{test_id}.txt"
  seed = 100

  run_cmd = "#{RUN} #{proj_clazz} #{test_config} #{seed}"
  output = `#{run_cmd}`.lines("\n").select{|line| /^[^#-]/.match(line) }.join
  
  File.write(program_output_file, output)
  
  correct_output = File.read(correct_output_file)
  if output == correct_output
      STDERR.puts "#{proj_name}/#{conf_name} OK."
  else
      STDERR.puts "#{proj_name}/#{conf_name} FAILED"
  end
end


Dir.chdir(test_dir)

