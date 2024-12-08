import argparse

# Moves and their decompositions ((X, Y) -> hex)
moves = {
    (1, 2): 0x01,
    (-1, 2): 0x02,
    (-2, 1): 0x04,
    (-2, -1): 0x08,
    (-1, -2): 0x10,
    (1, -2): 0x20,
    (2, -1): 0x40,
    (2, 1): 0x80
}

# Moves and their decompositions (hex → (X, Y))
orig_moves = [
    (1, 2),
    (-1, 2),
    (-2, 1),
    (-2, -1),
    (-1, -2),
    (1, -2),
    (2, -1),
    (2, 1),
]

rows, cols = 5, 5  # Dimensions of the chessboard
visited_squares = [[0 for _ in range(cols)] for _ in range(rows)]
solution_path = []  # List to keep track of the path (in coordinates)


def get_valid_moves(square):
    """
    Given a new square (x, y), calculates the valid moves that stay within the board boundaries
    and are not visited.
    """
    # Calculate the new possible moves by adding the move offsets to the new square
    new_moves = [(square[0] + dx, square[1] + dy) for dx, dy in orig_moves]

    # Filter moves to remove those that go out of bounds or are already visited
    valid_moves = [
        (x, y) for x, y in new_moves
        if 0 <= x < rows and 0 <= y < cols and visited_squares[x][y] == 0
    ]

    return valid_moves


def compute_solution(square, move_count=1):
    """
    Recursive function to compute the solution for the Knight's Tour problem.
    """
    current_x, current_y = square

    # Mark the current position as visited
    visited_squares[current_x][current_y] = 1

    # Add the current position to the solution path (in coordinates)
    solution_path.append(square)

    # If the knight has visited all squares (solution found)
    if move_count == rows * cols:
        return True

    # Get the list of valid moves from the current square
    pos_moves = get_valid_moves((current_x, current_y))

    if not pos_moves:
        # If no valid moves, backtrack by marking the current square as unvisited
        visited_squares[current_x][current_y] = 0
        solution_path.pop()  # Remove the last move from the path
        return False  # No valid move, backtrack to previous state

    # Otherwise, we have valid moves, try each one
    for move in pos_moves:
        # Recursively call compute_solution for the next valid move
        if compute_solution(move, move_count + 1):
            return True  # If a valid solution is found, return True

    # If none of the possible moves lead to a solution, backtrack
    visited_squares[current_x][current_y] = 0
    solution_path.pop()  # Remove the last move from the path
    return False  # Backtrack if no solution found in this path


def write_coordinates_to_file(coordinate_path, filename="solution_output.txt"):
    """
    Writes the solution path (in coordinates) to a file, one tuple per line.
    """
    with open(filename, 'w') as file:
        for coord in coordinate_path:
            file.write(f"{coord}\n")


def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Solve Knight's Tour problem.")
    parser.add_argument('x', type=int, help="Starting x position")
    parser.add_argument('y', type=int, help="Starting y position")
    args = parser.parse_args()

    x_start = args.x
    y_start = args.y

    if compute_solution((x_start, y_start)):
        print("Solution Found!")
        write_coordinates_to_file(solution_path)  # Write the coordinates to a file
    else:
        print("No solution exists.")


if __name__ == "__main__":
    main()
