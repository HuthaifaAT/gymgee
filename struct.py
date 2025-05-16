import os
from pathlib import Path

# Define the directory structure
structure = {
    "lib": {
        "core": {
            "constants": [
                "app_constants.dart",
                "app_strings.dart",
                "app_theme.dart"
            ],
            "errors": [
                "exceptions.dart",
                "failures.dart"
            ],
            "network": [
                "network_info.dart",
                "api_client.dart"
            ],
            "utils": [
                "date_formatter.dart",
                "validators.dart",
                "analytics_helper.dart"
            ],
            "widgets": {
                "buttons": [],
                "cards": [],
                "dialogs": [],
                "loaders": []
            }
        },
        "data": {
            "datasources": {
                "local": [
                    "app_database.dart",
                    "workout_local_datasource.dart",
                    "user_local_datasource.dart"
                ],
                "remote": [
                    "workout_remote_datasource.dart",
                    "user_remote_datasource.dart"
                ]
            },
            "models": [
                "exercise_model.dart",
                "workout_model.dart",
                "workout_log_model.dart",
                "user_model.dart",
                "personal_record_model.dart"
            ],
            "repositories": [
                "workout_repository_impl.dart",
                "exercise_repository_impl.dart",
                "user_repository_impl.dart"
            ]
        },
        "domain": {
            "entities": [
                "exercise.dart",
                "workout.dart",
                "workout_log.dart",
                "user.dart",
                "personal_record.dart"
            ],
            "repositories": [
                "workout_repository.dart",
                "exercise_repository.dart",
                "user_repository.dart"
            ],
            "usecases": {
                "workout": [
                    "get_workout_history.dart",
                    "log_workout.dart",
                    "get_personal_records.dart"
                ],
                "user": [
                    "get_user.dart",
                    "update_user.dart"
                ]
            }
        },
        "presentation": {
            "bloc": {
                "workout": [
                    "workout_bloc.dart",
                    "workout_event.dart",
                    "workout_state.dart"
                ],
                "exercise": [
                    "exercise_bloc.dart",
                    "exercise_event.dart",
                    "exercise_state.dart"
                ],
                "timer": [
                    "timer_bloc.dart",
                    "timer_event.dart",
                    "timer_state.dart"
                ]
            },
            "pages": {
                "home": {
                    "home_page.dart": None,
                    "widgets": []
                },
                "workout": {
                    "workout_list_page.dart": None,
                    "workout_detail_page.dart": None,
                    "workout_in_progress_page.dart": None,
                    "widgets": []
                },
                "stats": {
                    "stats_dashboard_page.dart": None,
                    "widgets": []
                },
                "history": {
                    "workout_history_page.dart": None,
                    "widgets": []
                },
                "profile": {
                    "profile_page.dart": None,
                    "widgets": []
                }
            },
            "widgets": [
                "exercise_card.dart",
                "workout_timer.dart",
                "set_tracker.dart",
                "progress_chart.dart"
            ]
        },
        "config": {
            "routes": [
                "app_router.dart",
                "route_names.dart"
            ],
            "injection": [
                "dependency_injection.dart"
            ]
        },
        "app.dart": None,
        "main.dart": None
    }
}

def create_structure(base_path, structure):
    for name, content in structure.items():
        path = base_path / name
        if content is None:
            # It's a file
            path.touch()
            print(f"Created file: {path}")
        elif isinstance(content, dict):
            # It's a directory with more content
            path.mkdir(exist_ok=True)
            print(f"Created directory: {path}")
            create_structure(path, content)
        elif isinstance(content, list):
            # It's a directory with files
            path.mkdir(exist_ok=True)
            print(f"Created directory: {path}")
            for file_name in content:
                file_path = path / file_name
                file_path.touch()
                print(f"Created file: {file_path}")

# Get current working directory
current_dir = Path.cwd()

# Create the structure
create_structure(current_dir, structure)

print("\nDirectory structure created successfully!")