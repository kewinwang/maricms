##
# MariCMS
# Copyright 2011 金盏信息科技(上海)有限公司 | MariGold Information Tech. Co,. Ltd.
# http://www.maricms.com

# This file is part of MariCMS, an open source content management system.

# MariGold MariCMS is free software: you can redistribute it and/or
# modify it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, version 3 of the License.
# 
# Under the terms of the GNU Affero General Public License you must release the
# complete source code for any application that uses any part of MariCMS
# (system header files and libraries used by the operating system are excluded).
# These terms must be included in any work that has MariCMS components.
# If you are developing and distributing open source applications under the
# GNU Affero General Public License, then you are free to use MariCMS.
# 
# If you are deploying a web site in which users interact with any portion of
# MariCMS over a network, the complete source code changes must be made
# available.  For example, include a link to the source archive directly from
# your web site.
# 
# For OEMs, ISVs, SIs and VARs who distribute MariCMS with their products,
# and do not license and distribute their source code under the GNU
# Affero General Public License, MariGold provides a flexible commercial
# license.
# 
# To anyone in doubt, we recommend the commercial license. Our commercial license
# is competitively priced and will eliminate any confusion about how
# MariCMS can be used and distributed.
# 
# MariCMS is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public License for more
# details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with MariCMS.  If not, see <http://www.gnu.org/licenses/>.
# 
# Attribution Notice: MariCMS is an Original Work of software created
# by  金盏信息科技(上海)有限公司 | MariGold Information Tech. Co,. Ltd.
##

class RPageD
  # this is the relationship between page and ds

  include Mongoid::Document

  field :new_d_name, :type => String
  field :query_hash, :type => Hash

  belongs_to :d
  embedded_in :page
  
  def default_query
    if self.d.ds_type == "Tree"
      ret = self.d.get_klass.roots
    else
      ret = self.d.get_klass
    end
    
    queried = false
    
    self.query_hash.each do |k,v|
    #i know it is not good
      unless v.blank?
        if(k.to_s == "excludes")
          cond = {}
          ar = v.split("=")
          if ar.size > 0
            cond[ar[0].strip] = ar[1].strip
            ret = ret.send(k, cond)
          end
        elsif(k.to_s == "limit")
          ret = ret.send(k, v.to_i)
        else
          ret = ret.send(k, v)
        end
        queried = true
      end
    end

    if queried
      ret
    else
      ret.all
    end
  end
end