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

    tpm = Topolys::Model.new

    return true
  end
end

# register the measure to be used by the application
CheckModel.new.registerWithApplication
