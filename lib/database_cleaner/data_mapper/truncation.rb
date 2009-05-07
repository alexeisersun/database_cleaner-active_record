module DataMapper
  module Adapters
    
    class MysqlAdapter < DataObjectsAdapter
      
      # taken from http://github.com/godfat/dm-mapping/tree/master
      def storage_names(repository = :default)
        query 'SHOW TABLES'
      end
      
      def truncate_table(table_name)
        execute("TRUNCATE TABLE #{quote_table_name(table_name)};")
      end
      
      # copied from activerecord
      def disable_referential_integrity
        old = query("SELECT @@FOREIGN_KEY_CHECKS;")
        begin
          execute("SET FOREIGN_KEY_CHECKS = 0;")
          yield
        ensure
          execute("SET FOREIGN_KEY_CHECKS = #{old};")
        end
      end
    
    end

    class Sqlite3Adapter < DataObjectsAdapter
      
      # taken from http://github.com/godfat/dm-mapping/tree/master
      def storage_names(repository = :default)
        # activerecord-2.1.0/lib/active_record/connection_adapters/sqlite_adapter.rb: 177
        sql = <<-SQL.compress_lines
          SELECT name
          FROM sqlite_master
          WHERE type = 'table' AND NOT name = 'sqlite_sequence'
        SQL
        # activerecord-2.1.0/lib/active_record/connection_adapters/sqlite_adapter.rb: 181
        query sql
      end
      
      def truncate_table(table_name)
        execute("DELETE FROM #{quote_table_name(table_name)};")
      end
      
      # this is a no-op copied from activerecord
      # i didn't find out if/how this is possible
      # activerecord also doesn't do more here
      def disable_referential_integrity
        yield
      end
      
    end


    # FIXME
    # this definitely won't work!!!
    # i basically just copied activerecord code to get a rough idea what they do
    # anyways, i don't have postgres available, so i won't be the one to write this.
    # maybe the stub codes below gets some postgres/datamapper user going, though.
    class PostgresAdapter < DataObjectsAdapter
      
      # taken from http://github.com/godfat/dm-mapping/tree/master
      def storages
        sql = <<-SQL.compress_lines
          SELECT table_name FROM "information_schema"."tables"
          WHERE table_schema = current_schema()
        SQL
        query(sql)
      end
      
      def truncate_table(table_name)
        execute("TRUNCATE TABLE #{quote_table_name(table_name)};")
      end
      
      # FIXME
      # copied from activerecord
      def supports_disable_referential_integrity?
        version = query("SHOW server_version")[0][0].split('.')
        (version[0].to_i >= 8 && version[1].to_i >= 1) ? true : false
      rescue
        return false
      end
 
      # FIXME
      # copied unchanged from activerecord
      def disable_referential_integrity(repository = :default)
        if supports_disable_referential_integrity? then
          execute(storage_names(repository).collect do |name| 
            "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" 
          end.join(";"))
        end
        yield
      ensure
        if supports_disable_referential_integrity? then
          execute(storage_names(repository).collect do |name| 
            "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL" 
          end.join(";"))
        end
      end
      
    end

  end
  
end


module DatabaseCleaner::DataMapper
  class Truncation

    def initialize(options={})
      if !options.empty? && !(options.keys - [:only, :except]).empty?
        raise ArgumentError, "The only valid options are :only and :except. You specified #{options.keys.join(',')}."
      end
      if options.has_key?(:only) && options.has_key?(:except)
        raise ArgumentError, "You may only specify either :only or :either.  Doing both doesn't really make sense does it?" 
      end

      @only = options[:only]
      @tables_to_exclude = (options[:except] || []) << 'migration_info' # dm-migrations calls it like so
    end
    
    
    def start(repository = :default)
      # no-op
    end

    def clean(repository = :default)
      adapter = DataMapper.repository(repository).adapter
      adapter.disable_referential_integrity do
        tables_to_truncate.each do |table_name|
          adapter.truncate_table table_name
        end
      end
  end

  private

    # no idea if this works
    def tables_to_truncate(repository = :default)
      (@only || DataMapper.repository(repository).adapter.storage_names(repository)) - @tables_to_exclude
    end

  end

end
