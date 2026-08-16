"""Data warehouse schema and SQL operations."""


def create_core_tables():
    """Create core schema tables."""
    pass


def create_staging_tables():
    """Create staging schema tables."""
    pass


def insert_to_core(data):
    """Insert data into core tables."""
    pass


def insert_to_staging(data):
    """Insert data into staging tables."""
    pass


def run_dbt_transformations():
    """Run dbt model transformations."""
    pass


__all__ = [
    'create_core_tables',
    'create_staging_tables',
    'insert_to_core',
    'insert_to_staging',
    'run_dbt_transformations',
]
