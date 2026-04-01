import sqlite3

def verify():
    try:
        conn = sqlite3.connect('backup_financiero_2026-03-31.db')
        cursor = conn.cursor()
        
        # Obtener todas las tablas existentes para ver los nombres reales
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = [t[0] for t in cursor.fetchall()]
        print(f"Tablas encontradas ({len(tables)}): {tables}")
        
        print("\n--- Conteo de Registros ---")
        for table in tables:
            if not table.startswith('sqlite_'):
                try:
                    cursor.execute(f'SELECT count(*) FROM "{table}"')
                    count = cursor.fetchone()[0]
                    print(f"- {table}: {count}")
                except Exception as e:
                    print(f"- {table}: Error {e}")
                
        conn.close()
    except Exception as e:
        print(f"Error al leer DB: {e}")

if __name__ == '__main__':
    verify()
