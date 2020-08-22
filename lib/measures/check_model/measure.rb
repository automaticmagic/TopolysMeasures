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
        boundary_type = surface.outsideBoundaryCondition
        gross_area = surface.grossArea

        sub_surface_structs = []
        surface.subSurfaces.each do |sub_surface|
          ss_points = (t*sub_surface.vertices).map{|v| Topolys::Point3D.new(v.x, v.y, v.z) }
          ss_gross_area = sub_surface.grossArea
          sub_surface_type = sub_surface.subSurfaceType
          sub_surface_structs << {sub_surface: sub_surface, sub_surface_type: sub_surface_type, gross_area: gross_area, points: ss_points, wire: nil}
        end

        surface_structs << {surface: surface, surface_type: surface_type, boundary_type: boundary_type, gross_area: gross_area, points: points, minz: minz, space: space, sub_surfaces: sub_surface_structs, face: nil, shell: nil}
      end
    end

    # map OpenStudio enums down to the reduced set of enums in our exported JSON
    surface_structs.each_index do |i|
      case surface_structs[i][:boundary_type]
      when 'Surface', 'Adiabatic'
        surface_structs[i][:boundary_type] = 'Adiabatic'
      when 'Outdoors'
        surface_structs[i][:boundary_type] = 'Outdoors'
      else
        surface_structs[i][:boundary_type] = 'Ground'
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
      puts wire.points
      puts "normal"
      puts wire.normal

      holes = []
      sub_surfaces = surface_structs[i][:sub_surfaces]
      sub_surfaces.each_index do |j|
        ss_points = sub_surfaces[j][:points]
        ss_vertices = tpm.get_vertices(ss_points)
        ss_wire = tpm.get_wire(ss_vertices)
        puts "ss_wire = #{ss_wire}"
        sub_surfaces[j][:wire] = ss_wire
        holes << ss_wire
      end

      face = tpm.get_face(wire, holes)
      if face.nil?
        # todo: log error
        puts "cannot construct face for #{surface_structs[i][:surface].nameString}"
        return false
      end

      puts "face = #{face}"
      face.attributes[:surface] = surface_structs[i][:surface]
      face.attributes[:surface_name] = surface_structs[i][:surface].nameString
      face.attributes[:surface_type] = surface_structs[i][:surface_type]
      face.attributes[:boundary_type] = surface_structs[i][:boundary_type]

      surface_structs[i][:face] = face

      face.outer.edges.each do |edge|
        edge.attributes[:length] = edge.length if edge.attributes[:length].nil?
        edge.attributes[:surface_names] = [] if edge.attributes[:surface_names].nil?
        edge.attributes[:surface_names] << surface_structs[i][:surface].nameString
      end

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

    # save the full model
    tpm.save('full_tpm.json')

    # create a minimal model
    minimal_model = { faces: [] }
    tpm.faces.each do |face|
      minimal_face = face.attributes.clone
      minimal_face.delete(:surface)
      minimal_face[:edges] = []
      face.outer.edges.each do |edge|
        minimal_face[:edges] << edge.attributes.clone
      end
      minimal_model[:faces] << minimal_face
    end

    # save the minimal model
    File.open('minimal_model.json', 'w') do |file|
      file.puts JSON.pretty_generate(minimal_model)
    end

    return true
  end
end

# register the measure to be used by the application
CheckModel.new.registerWithApplication
