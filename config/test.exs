import Config

ash_domains = [AshGleam.TestDomain, AshGleam.TestPolicyDomain]

config :ash_gleam,
  output: "src/test_generated",
  default_ash_domains: ash_domains,
  ash_domains: ash_domains
