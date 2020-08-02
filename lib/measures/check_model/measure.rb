begin
  # try to load from the gem
  require 'topolys'
rescue LoadError
  require File.join(File.dirname(__FILE__), 'resources/geometry.rb')
  require File.join(File.dirname(__FILE__), 'resources/model.rb')
  require File.join(File.dirname(__FILE__), 'resources/transformation.rb')
  require File.join(File.dirname(__FILE__), 'resources/version.rb')
end

# start the measure
class CheckModel < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'CheckModel'
  end

  # human readable description
  def description
    return 'Uses Topolys to check a model'
  end

  # human readable description of modeling approach
  def modeler_description
    return ''
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    return args
  end
  
  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
   
    # get a list of OpenStudio Surfaces along with some other properties
    surface_structs = []
    model.getSpaces.each do |space|
      t = space.siteTransformation
      space.surfaces.each do |surface|
        points = (t*surface.vertices).map{|v| Topolys::Point3D.new(v.x, v.y, v.z) }
        minz = (points.map{|p| p.z}).min
        surface_type = surface.surfaceType
        gross_area = surface.grossArea
        surface_structs << {surface: surface, surface_type: surface_type, gross_area: gross_area, points: points, minz: minz, space: space, face: nil, shell: nil}
      end
    end
    
    # sort the OpenStudio Surfaces
    surface_types = ['Floor', 'RoofCeiling', 'Wall']
    surface_structs.sort! do |x, y| 
      if ( x[:surface_type] != y[:surface_type] )
        x[:surface_type] <=> y[:surface_type]
      elsif ( x[:minz] != y[:minz] )
        x[:minz] <=> y[:minz]
      else
        x[:surface_type] <=> y[:surface_type]
      end
    end
    #surface_structs.each {|s| puts "#{s[:surface_type]}, #{s[:gross_area]}"}
    
    # create the Topolys Model
    tpm = Topolys::Model.new
    
    # add a Topolys Face for each OpenStudio Surface
    n = surface_structs.size
    (0...n).each do |i|
      points = surface_structs[i][:points]
      puts "points = #{points}"
      vertices = tpm.get_vertices(points)
      #puts "vertices = #{vertices}" # DLM: why does this line blow up?
      wire = tpm.get_wire(vertices)
      puts "wire = #{wire}"
      face = tpm.get_face(wire, [])
      puts "face = #{face}"
      face.attributes[:surface] = surface_structs[i][:surface]
      face.attributes[:surface_type] = surface_structs[i][:surface_type]
      face.attributes[:space] = surface_structs[i][:space]
      surface_structs[i][:face] = face
    end
    
    # create a Topolys Shell for each OpenStudio Space
    model.getSpaces.each do |space|
      structs = surface_structs.select{|ss| ss[:space].handle == space.handle}
      faces = structs.map{|ss| ss[:face]}
      #puts "faces = #{faces}" # DLM: why does this line blow up?
      puts "faces = #{faces.size}"
      shell = tpm.get_shell(faces)
      shell.attributes[:space] = space
      puts "shell = #{shell}, closed = #{shell.closed?}"
    end
    
    # find OpenStudio Surfaces connected by edges
    model.getSurfaces.each do |surface|
      face = tpm.faces.find{|f| f.attributes[:surface].handle == surface.handle}
      
      if !face
        puts "Ooops, can't find Face for Surface #{surface.nameString}"
      end
      
      tpm.faces.each do |f|
        next if f.id == face.id
        
        shared_edges = face.shared_outer_edges(f)
        if shared_edges && !shared_edges.empty?
          length = 0
          shared_edges.map{|e| length += e.length}
          puts "Surface #{face.attributes[:surface].nameString} is connected to Surface #{f.attributes[:surface].nameString} by #{shared_edges.size} shared edges with length #{length}"
        end
      end
    end
    
    # install graphviz and make sure dot is in the system path
    tpm.save_graphviz('shell.dot')
    system('dot shell.dot -Tpdf -o shell.pdf')

    return true
  end
end

# register the measure to be used by the application
CheckModel.new.registerWithApplication
