mutable struct AIConfig
  base_url::String
  model::String
  api_key::String
  schema::Any
  base_config::NamedTuple
end

global_config = Ref{Union{AIConfig,Nothing}}(nothing)

"""
    configure_ai(file_path::String)

Configure the AI model to be used for the analysis from a YAML file.

# Example YAML configuration file

```yaml
model: phi4
api_key: ...
base_url: http://127.0.0.1:11434  # ollama
```
"""
function configure_ai(file_path::String)
  config = YAML.load_file(file_path)
  base_url = config["base_url"]
  model = config["model"]
  api_key = config["api_key"]

  schema = PT.OllamaSchema()
  base_config = (
    model=model,
    api_key=api_key,
    config=RetryConfig(catch_errors=true, max_retries=5, max_calls=10000),
  )
  global_config[] = AIConfig(base_url, model, api_key, schema, base_config)
end

function get_ai_config()
  if isnothing(global_config[])
    error("AI configuration not set. Please call configure_ai() first.")
  end
  return global_config[]
end
