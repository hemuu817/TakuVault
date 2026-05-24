Rake::Task["db:schema:dump"].enhance do
  file = Rails.root.join("db/structure.sql")
  content = File.read(file)
  File.write(file, content.gsub(/^SET transaction_timeout.*\n/, ""))
end
