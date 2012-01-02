desc 'Run all unit, functional and integration tests'
task :quick_test do
  errors = %w(quick_test:units quick_test:functionals quick_test:integration).collect do |task|
    begin
      Rake::Task[task].invoke
      nil
    rescue => e
      task
    end
  end.compact
  abort "Errors running #{errors.to_sentence(:locale => :en)}!" if errors.any?
end

namespace :quick_test do
  Rake::TestTask.new(:recent => "db:test:quick_prepare") do |t|
    since = TEST_CHANGES_SINCE
    touched = FileList['test/**/*_test.rb'].select { |path| File.mtime(path) > since } +
      recent_tests('app/models/**/*.rb', 'test/unit', since) +
      recent_tests('app/controllers/**/*.rb', 'test/functional', since)

    t.libs << 'test'
    t.verbose = true
    t.test_files = touched.uniq
  end
  Rake::Task['test:recent'].comment = "Test recent changes"

  Rake::TestTask.new(:uncommitted => "db:test:quick_prepare") do |t|
    def t.file_list
      if File.directory?(".svn")
        changed_since_checkin = silence_stderr { `svn status` }.map { |path| path.chomp[7 .. -1] }
      elsif File.directory?(".git")
        changed_since_checkin = silence_stderr { `git ls-files --modified --others` }.map { |path| path.chomp }
      else
        abort "Not a Subversion or Git checkout."
      end

      models      = changed_since_checkin.select { |path| path =~ /app[\\\/]models[\\\/].*\.rb$/ }
      controllers = changed_since_checkin.select { |path| path =~ /app[\\\/]controllers[\\\/].*\.rb$/ }

      unit_tests       = models.map { |model| "test/unit/#{File.basename(model, '.rb')}_test.rb" }
      functional_tests = controllers.map { |controller| "test/functional/#{File.basename(controller, '.rb')}_test.rb" }

      unit_tests.uniq + functional_tests.uniq
    end

    t.libs << 'test'
    t.verbose = true
  end
  Rake::Task['test:uncommitted'].comment = "Test changes since last checkin (only Subversion and Git)"

  Rake::TestTask.new(:units => "db:test:quick_prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/unit/**/*_test.rb'
    t.verbose = true
  end
  Rake::Task['test:units'].comment = "Run the unit tests in test/unit"

  Rake::TestTask.new(:functionals => "db:test:quick_prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/functional/**/*_test.rb'
    t.verbose = true
  end
  Rake::Task['test:functionals'].comment = "Run the functional tests in test/functional"

  Rake::TestTask.new(:integration => "db:test:quick_prepare") do |t|
    t.libs << "test"
    t.pattern = 'test/integration/**/*_test.rb'
    t.verbose = true
  end
  Rake::Task['test:integration'].comment = "Run the integration tests in test/integration"

  Rake::TestTask.new(:benchmark => 'db:test:quick_prepare') do |t|
    t.libs << 'test'
    t.pattern = 'test/performance/**/*_test.rb'
    t.verbose = true
    t.options = '-- --benchmark'
  end
  Rake::Task['test:benchmark'].comment = 'Benchmark the performance tests'

  Rake::TestTask.new(:profile => 'db:test:quick_prepare') do |t|
    t.libs << 'test'
    t.pattern = 'test/performance/**/*_test.rb'
    t.verbose = true
  end
  Rake::Task['test:profile'].comment = 'Profile the performance tests'

  Rake::TestTask.new(:plugins => :environment) do |t|
    t.libs << "test"

    if ENV['PLUGIN']
      t.pattern = "vendor/plugins/#{ENV['PLUGIN']}/test/**/*_test.rb"
    else
      t.pattern = 'vendor/plugins/*/**/test/**/*_test.rb'
    end

    t.verbose = true
  end
  Rake::Task['test:plugins'].comment = "Run the plugin tests in vendor/plugins/*/**/test (or specify with PLUGIN=name)"
end

namespace :db do
  namespace :test do
    desc 'Do not drop the database'
    task :quick_prepare => :load_config do
      ActiveRecord::Base.establish_connection(:test)
      ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0')
      ActiveRecord::Base.connection.tables.each do |table|
        ActiveRecord::Base.connection.execute("truncate #{table}")
      end
    end
  end
end