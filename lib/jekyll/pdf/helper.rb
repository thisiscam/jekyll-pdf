module Jekyll
  module PDF
    module Helper
      def fix_relative_paths
        # Deprecated in favor of rewrite_relative_paths to avoid mutating page output
        self.output = rewrite_relative_paths(output)
      end

      # Returns a rewritten copy of html with absolute paths mapped to file:// in _site
      def rewrite_relative_paths(html)
        return html if html.nil?

        rewritten = html.dup
        baseurl = site.baseurl.to_s
        if !baseurl.empty?
          rewritten.gsub!(/(href|src)=(['"])#{Regexp.escape(baseurl)}\//, "\\1=\\2file://#{site.dest}/")
        end

        # Rewrite absolute root paths to file:// site.dest
        rewritten.gsub!(/(href|src)=(['"])\//, "\\1=\\2file://#{site.dest}/")
        rewritten
      end
    end
  end
end
