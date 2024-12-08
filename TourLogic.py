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
solution_path = []  # List to keep track of the path (in hex values)


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


def convert_to_hex_path():
    """
    Converts the path of (x, y) positions to the corresponding hex values using the `moves` dictionary.
    """
    hex_path = []
    for i in range(1, len(solution_path)):
        prev_x, prev_y = solution_path[i - 1]
        curr_x, curr_y = solution_path[i]
        move = (curr_x - prev_x, curr_y - prev_y)  # Calculate the move (dx, dy)
        if move in moves:
            hex_path.append(moves[move])  # Add the corresponding hex value (as integer)
        else:
            print(f"Invalid move from {(prev_x, prev_y)} to {(curr_x, curr_y)}")
    return hex_path


def write_solution_to_file(hex_path, filename="solution_output"):
    """
    Writes the solution path (in hex) to a file in the format:
    @00 01
    @01 08
    @02 10
    ...
    """
    with open(filename, 'w') as file:
        for i, hex_value in enumerate(hex_path):
            if i != len(hex_path) - 1:
                file.write(f"@{i:02X} {hex_value:02X}\n")
            else:
                file.write(f"@{i:02X} {hex_value:02X}")


def main():
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Solve Knight's Tour problem.")
    parser.add_argument('x', type=int, help="Starting x position")
    parser.add_argument('y', type=int, help="Starting y position")
    args = parser.parse_args()

    x_start = args.x
    y_start = args.y

    if compute_solution((x_start, y_start)):
        print("Solution found!")
        print("Path taken (in coordinates) from (" + str(x_start) + ", " + str(y_start) +  "):", solution_path[1:])  # Print the solution path in coordinates
        # Write the hex path to a file
        write_solution_to_file(convert_to_hex_path())
    else:
        print("No solution exists.")


if __name__ == "__main__":
    main()
