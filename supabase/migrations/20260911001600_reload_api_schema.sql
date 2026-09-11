-- Make newly added trusted RPCs visible to PostgREST immediately after deployment.
notify pgrst,'reload schema';
