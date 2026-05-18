package pg

func PSQLArgs(sqlOrFile []string) []string {
	args := []string{
		"run",
		"--rm",
		"postgres-client",
		"sh",
		"-ec",
	}

	command := `PGPASSWORD="$POSTGRES_PASSWORD" psql -h haproxy -p 5000 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1`
	for _, item := range sqlOrFile {
		command += " " + item
	}

	return append(args, command)
}
