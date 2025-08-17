module Jekyll
  module PDF
    module Helper
      def fix_relative_paths
        return if output.nil?

        baseurl = site.baseurl.to_s
        if !baseurl.empty?
          output.gsub!(/(href|src)=(['"])#{Regexp.escape(baseurl)}\//, "\\1=\\2file://#{site.dest}/")
        end

        # Rewrite absolute root paths to file:// site.dest
        output.gsub!(/(href|src)=(['"])\//, "\\1=\\2file://#{site.dest}/")
      end
    end
  end
end
