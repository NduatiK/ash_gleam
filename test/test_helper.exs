ExUnit.start()

Application.put_env(:ash_gleam, :ash_domains, [AshGleam.TestDomain, AshGleam.TestPolicyDomain])
AshGleam.GeneratedGleamHelper.compile_and_load!()
